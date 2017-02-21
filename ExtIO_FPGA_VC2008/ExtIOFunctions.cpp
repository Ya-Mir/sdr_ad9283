/*

	Written by Andrus Aaslaid, ES1UVB
	andrus.aaslaid(6)gmail.com

	http://uvb-76.net

	This source code is licensed as Creative Commons Attribution-ShareAlike
	(CC BY-SA). 
	
	From http://creativecommons.org:

		This license lets others remix, tweak, and build upon your work even for commercial purposes, as long as they 
		credit you and license their new creations under the identical terms. This license is often compared to 
		“copyleft” free and open source software licenses. All new works based on yours will carry the same license, 
		so any derivatives will also allow commercial use. This is the license used by Wikipedia, and is recommended 
		for materials that would benefit from incorporating content from Wikipedia and similarly licensed projects. 


	This DLL provides an empty core for implementing hardware support functionality
	for the Winrad Software Defined Radio (SDR) application, created by Jeffrey Pawlan (WA6KBL)
	(www.winrad.org) and its offsprings supporting the same ExtIO DLL format,
	most notably the outstanding HDSDR software (hdsdr.org)

	As the Winrad source is written on Borland C-Builder environment, there has been very little 
	information available of how the ExtIO DLL should be implemented on Microsoft Visual Studio 2008
	(VC2008) environment and the likes. 

	This example is filling this gap, providing the empty core what can be compiled as appropriate 
	DLL working for HDSDR

	Note, that Winrad and HDSDR are sometimes picky about the DLL filename. The ExtIO_blaah.dll for example,
	works, while ExtIODll.dll does not. I havent been digging into depths of that. It is just that if your
	custom DLL refuses to be recognized by application for no apparent reason, trying to change the DLL filename
	may be a good idea.

	To have the DLL built with certain name can be achieved changing the LIBRARY directive inside ExtIODll.def


	Revision History:

	30.05.2011	-	Initial 
	22.04.2012	-	Cleaned up for public release
	01.12.2016	-	upd for ADC 96 MHz, 96 kHz

*/


#include "ExtIOFunctions.h"

#include <windows.h>
#include <stdio.h>
#include <math.h>
#include <winsock.h>
#pragma comment (lib, "wsock32.lib")
#include <stdexcept>

using namespace std;

#define OSC_FREQ 96000000

int frequency = 5000000;
short iq_data[1024];

void (* ExtIOCallback)(int, int, float, void *) = NULL;

HANDLE TriggerEvent;//HANDLE обработчика
HANDLE hTimer = NULL;
HANDLE hTimerQueue = NULL;
bool timer_started = false;

WSADATA wsda;
SOCKET udp_socket;
SOCKADDR_IN addr, remote_addr;

SOCKET udp_fr_socket = NULL;
struct sockaddr_in udp_fr_client, udp_fr_server;

void send_frequency(int data)
{
	char buffer[60];
	unsigned char data_to_send[10];
	int res = 0;
	double tmp;
	int fr = data;

	if (data == 0) {data = 10;}

	tmp = (double)data * (1<<24)/ OSC_FREQ;
	data = (int)tmp;

	data_to_send[0] = 0x13;//header
	data_to_send[1] = 0x57;//header
	data_to_send[2] = 0x9a;//header
	data_to_send[3] = (unsigned char)(data&0xff);//7-0
	data_to_send[4] = (unsigned char)((data>>8)&0xff);//15-8
	data_to_send[5] = (unsigned char)((data>>16)&0xff);//23-16
	data_to_send[6] = 0xaa;
	data_to_send[7] = 0xff;
	data_to_send[8] = 0xff;
	data_to_send[9] = 0xff;

	/** send the packet **/
	res = sendto(udp_fr_socket, (char*)data_to_send, 9, 0, (struct sockaddr*)&udp_fr_client, sizeof(udp_fr_client));
	sprintf (buffer, "SEND=%d, fr=%d, data=%d\n", res, fr, data);
	OutputDebugString(buffer);
	sprintf (buffer, "b1=%d, b2=%d, b3=%d\n", data_to_send[3], data_to_send[4], data_to_send[5]);
	OutputDebugString(buffer);

}

void create_udp_tx_server(void)
{
	char broadcast = 1;
	WSAStartup(MAKEWORD(1,1), &wsda);
	udp_fr_socket = socket(AF_INET, SOCK_DGRAM, 0);//socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if(udp_fr_socket == SOCKET_ERROR){OutputDebugString("Socket error 3\n");return;}

	/** you need to set this so you can broadcast **/
	if (setsockopt(udp_fr_socket, SOL_SOCKET, SO_BROADCAST, &broadcast, sizeof broadcast) == -1) {
		OutputDebugString("Socket error 4\n");
	}

	udp_fr_client.sin_family = AF_INET;
	udp_fr_client.sin_addr.s_addr = INADDR_BROADCAST;
	udp_fr_client.sin_port = htons(1024);
	//if (bind(udp_fr_socket, (struct sockaddr*)&udp_fr_client, sizeof(udp_fr_client)) == SOCKET_ERROR) {OutputDebugString("Socket error 5\n");}

	/*
	udp_fr_server.sin_family = AF_INET;
	//udp_fr_server.sin_addr.s_addr = inet_addr("192.168.0.44");
	udp_fr_server.sin_addr.s_addr = INADDR_ANY;
	udp_fr_server.sin_port = htons(1024);
	*/

}

void destruct_udp_tx_server(void)
{
	closesocket(udp_fr_socket);
	WSACleanup();
}

void create_udp_listener(void)
{
   WSAStartup(MAKEWORD(1,1), &wsda);
   udp_socket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);

   if(udp_socket == SOCKET_ERROR){OutputDebugString("Socket error 1\n");}
   addr.sin_family = AF_INET;
   addr.sin_port = htons(1024);//port
   addr.sin_addr.s_addr = INADDR_ANY;
   if(bind(udp_socket, (struct sockaddr *) &addr, sizeof(addr)) == SOCKET_ERROR){OutputDebugString("Socket error 2\n");}
}

void destruct_udp_listener(void)
{
   closesocket(udp_socket);
   WSACleanup();
}


//every 1 ms
VOID CALLBACK TimerTrigger(PVOID lpParam, BOOLEAN TimerOrWaitFired)
{
	int udp_result = 0;
	u_long udp_bytes = 0;
	static int page = 0;

	//OutputDebugString("TIMER\n");
	SetEvent(TriggerEvent);
	udp_result = ioctlsocket(udp_socket, FIONREAD, &udp_bytes);
	
	if (udp_bytes > 0)//we have data to read
	{
		int iRemoteAddrLen = sizeof(remote_addr);
		page^= 1;
		if (page == 0)
		{
			udp_result = recvfrom(udp_socket, (char*)&iq_data[0], 1024, 0, (struct sockaddr *) &remote_addr, &iRemoteAddrLen);
		}
		else
		{
			udp_result = recvfrom(udp_socket, (char*)&iq_data[512], 1024, 0, (struct sockaddr *) &remote_addr, &iRemoteAddrLen);
			(*ExtIOCallback)(512, 0, 0, iq_data);
		}
	}

}

void create_timer(void)
{
	if (timer_started == false)
	{	
		TriggerEvent = CreateEvent(NULL, TRUE, FALSE, NULL);//Создаем обработчик события для отслеживания состояния объекта
		hTimerQueue = CreateTimerQueue();//Создаем очередь таймера.
		CreateTimerQueueTimer( &hTimer, hTimerQueue,(WAITORTIMERCALLBACK)TimerTrigger, 0 , 0, 1, 0);
		timer_started = true;
	}
}

void destruct_timer(void)
{
	WaitForSingleObject(TriggerEvent, INFINITE);
	CloseHandle(TriggerEvent);
	DeleteTimerQueue(hTimerQueue);
	timer_started = false;
}




extern "C" bool __stdcall InitHW(char *name, char *model, int& type)
{
static bool first = true;

	type = 3; // 4 ==> data returned via the sound card

	if(first)
	{
		first = false;
	}

	strcpy(name, "SDR FPGA");	// change with the name of your HW
	strcpy(model, "SDR FPGA");	// change with the model of your HW
	//create_timer();
	return true;
}


extern "C" bool __stdcall OpenHW(void)
{
	create_udp_tx_server();
	return true;
}



extern "C" int __stdcall StartHW(long freq)
{
	create_udp_listener();
	create_timer();
	return 512;	// number of complex elements returned each
				// invocation of the callback routine
}


extern "C" void __stdcall StopHW(void)
{
	destruct_udp_listener();
	destruct_timer();
	return; // nothing to do with this specific HW
}



extern "C" void __stdcall CloseHW(void)
{
	destruct_udp_tx_server();
	return; // nothing to do with this specific HW
}


extern "C" int __stdcall SetHWLO(long LOfreq)
{	
	send_frequency((int)LOfreq);

	frequency = (int)LOfreq;
	OutputDebugString("frequency change\n");
	return 0; // return 0 if the frequency is within the limits the HW can generate
}


extern "C" long __stdcall GetHWLO(void)
{
	return (long)frequency;	//LOfreq;
}


extern "C" long __stdcall GetHWSR(void)
{
	return 96000;
}


extern "C" long __stdcall GetTune(void)
{
	return (long)frequency;
}



extern "C" int __stdcall GetStatus(void)
{
	return 0;
}


extern "C" void __stdcall TuneChanged(long freq)
{
	return;
}




extern "C" void __stdcall SetCallback(void (* Callback)(int, int, float, void *))
{
	ExtIOCallback = Callback;
	(*ExtIOCallback)(-1, 101, 0, NULL);			// sync lo frequency on display
	(*ExtIOCallback)(-1, 105, 0, NULL);			// sync tune frequency on display

		return;		// this HW does not return audio data through the callback device
					// nor it has the need to signal a new sampling rate.
}



extern "C" void __stdcall RawDataReady(long samprate, int *Ldata, int *Rdata, int numsamples)
{
	return;
}


