#import "TGCallPeerStateText.h"
#import "TGLocalization.h"

NSString *TGCallPeerStateSuffix(BOOL audioMuted, BOOL videoPaused, BOOL videoCall) {
	BOOL cameraOff = videoCall && videoPaused;
	if (audioMuted && cameraOff)
		return TGL(@"Call.PeerMicrophoneAndCameraOff", @"microphone and camera off");
	if (audioMuted)
		return TGL(@"Call.PeerMicrophoneOff", @"microphone off");
	if (cameraOff)
		return TGL(@"Call.PeerCameraOff", @"camera off");
	return nil;
}
