#ifndef TELEGRAM_TG_VOIP_JNI_H
#define TELEGRAM_TG_VOIP_JNI_H

#include <jni.h>

#ifdef __cplusplus
extern "C"{
#endif
void tgvoipRegisterNatives(JNIEnv* env);
#ifdef __cplusplus
}
#endif

#endif
