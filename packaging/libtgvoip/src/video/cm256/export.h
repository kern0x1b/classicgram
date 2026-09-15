#ifndef __CM256CC_EXPORT_H
#define __CM256CC_EXPORT_H

#if defined (__GNUC__) && (__GNUC__ >= 4)
#  define __CM256CC_EXPORT   __attribute__((visibility("default")))
#  define __CM256CC_IMPORT   __attribute__((visibility("default")))

#elif defined (_MSC_VER)
#  define __CM256CC_EXPORT   __declspec(dllexport)
#  define __CM256CC_IMPORT   __declspec(dllimport)

#else
#  define __CM256CC_EXPORT
#  define __CM256CC_IMPORT
#endif

#if !defined(cm256cc_STATIC)
#  if defined cm256cc_EXPORTS
#    define CM256CC_API __CM256CC_EXPORT
#  else
#    define CM256CC_API __CM256CC_IMPORT
#  endif
#else
#  define CM256CC_API
#endif

#endif 