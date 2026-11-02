package.preload['lib.jsoncfg'] = (function (...)
local PATH_SEPARATOR = "/"
if MONET_VERSION == nil then
    PATH_SEPARATOR = "\\"
end

local function deepcopy(o, seen)
    seen = seen or {}
    if o == nil then
        return nil
    end
    if seen[o] then
        return seen[o]
    end

    local no
    if type(o) == "table" then
        no = {}
        seen[o] = no

        for k, v in next, o, nil do
            no[deepcopy(k, seen)] = deepcopy(v, seen)
        end
        setmetatable(no, deepcopy(getmetatable(o), seen))
    else -- number, string, boolean, etc
        no = o
    end
    return no
end

local function deepmerge(a, b)
    for k, v in next, b, nil do
        if a[k] == nil then
            a[deepcopy(k)] = deepcopy(v)
        else
            if type(v) == "table" and type(a[k]) == "table" then
                deepmerge(a[k], v)
            end
        end
    end
end

local function load(default, filename, extension)
    local default = default or {}
    local extension = extension or ".json"
    local filename = filename or script.this.filename .. extension

    filename:gsub("\\", PATH_SEPARATOR)
    if MONET_VERSION ~= nil then
        filename:gsub("moonloader/", "monetloader/")
    end

    local filepath1 = getWorkingDirectory() .. PATH_SEPARATOR .. "config" .. PATH_SEPARATOR .. filename .. extension
    local filepath2 = getWorkingDirectory() .. PATH_SEPARATOR .. "config" .. PATH_SEPARATOR .. filename
    local filepath3 = filename

    local file = io.open(filepath1, "r")
    if not file then
        file = io.open(filepath2, "r")
    end
    if not file then
        file = io.open(filepath3, "r")
    end

    if file then
        local contents = file:read("*a")
        if #contents == 0 then
            file:close()
            return deepcopy(default)
        end
        local result, loaded = pcall(decodeJson, contents)
        file:close()
        if not result or not loaded then
            if not result then
                print("jsoncfg: failed to decode json, error:", loaded)
            end
            return deepcopy(default)
        end

        deepmerge(loaded, default)
        return loaded
    else
        return deepcopy(default)
    end
end

local function save(data, filename, extension)
    local extension = extension or ".json"
    local filename = filename or script.this.filename .. extension

    filename:gsub("\\", PATH_SEPARATOR)
    if MONET_VERSION ~= nil then
        filename:gsub("moonloader/", "monetloader/")
    end

    local filepath = getWorkingDirectory() .. PATH_SEPARATOR .. "config" .. PATH_SEPARATOR
    if filename:find(PATH_SEPARATOR, 1, true) ~= nil then
        local dir = filename:match(".*" .. PATH_SEPARATOR)
        createDirectory(dir)
        filepath = filename
    elseif filename:match("%" .. extension .. "$") ~= nil then
        createDirectory(filepath)
        filepath = filepath .. filename
    else
        createDirectory(filepath)
        filepath = filepath .. filename .. extension
    end

    local file, errstr = io.open(filepath, "w")
    if file then
        local result, encoded = pcall(encodeJson, data)
        if result then
            file:write(encoded)
        else
            print("jsoncfg: failed to encode json, error:", encoded)
        end
        file:close()
        return result
    else
        print("jsoncfg: failed to open file, error:", errstr)
        return false
    end
end

return {
    load = load,
    save = save,
} end)
package.preload['lib.android'] = (function (...)
if not MONET_VERSION then
    return setmetatable({}, {__index = function() return function() end end})
end

local ffi = require("ffi")
 
ffi.cdef[[
    /* Primitive types that match up with Java equivalents. */
    typedef uint8_t  jboolean; /* unsigned 8 bits */
    typedef int8_t   jbyte;    /* signed 8 bits */
    typedef uint16_t jchar;    /* unsigned 16 bits */
    typedef int16_t  jshort;   /* signed 16 bits */
    typedef int32_t  jint;     /* signed 32 bits */
    typedef int64_t  jlong;    /* signed 64 bits */
    typedef float    jfloat;   /* 32-bit IEEE 754 */
    typedef double   jdouble;  /* 64-bit IEEE 754 */
 
    /* "cardinal indices and sizes" */
    typedef jint     jsize;
 
    typedef void*           jobject;
    typedef jobject         jclass;
    typedef jobject         jstring;
    typedef jobject         jarray;
    typedef jarray          jobjectArray;
    typedef jarray          jbooleanArray;
    typedef jarray          jbyteArray;
    typedef jarray          jcharArray;
    typedef jarray          jshortArray;
    typedef jarray          jintArray;
    typedef jarray          jlongArray;
    typedef jarray          jfloatArray;
    typedef jarray          jdoubleArray;
    typedef jobject         jthrowable;
    typedef jobject         jweak;
 
    struct _jfieldID;                       /* opaque structure */
    typedef struct _jfieldID* jfieldID;     /* field IDs */
    
    struct _jmethodID;                      /* opaque structure */
    typedef struct _jmethodID* jmethodID;   /* method IDs */    
 
    typedef union jvalue {
        jboolean    z;
        jbyte       b;
        jchar       c;
        jshort      s;
        jint        i;
        jlong       j;
        jfloat      f;
        jdouble     d;
        jobject     l;
    } jvalue;
 
    typedef enum jobjectRefType {
        JNIInvalidRefType = 0,
        JNILocalRefType = 1,
        JNIGlobalRefType = 2,
        JNIWeakGlobalRefType = 3
    } jobjectRefType;
    
    typedef struct {
        const char* name;
        const char* signature;
        void*       fnPtr;
    } JNINativeMethod;
 
    typedef const struct JNINativeInterface* C_JNIEnv;
    typedef const struct JNIInvokeInterface* JavaVM;
    typedef const struct JNINativeInterface* JNIEnv;
    struct JNINativeInterface {
        void*       reserved0;
        void*       reserved1;
        void*       reserved2;
        void*       reserved3;
    
        jint        (*GetVersion)(JNIEnv *);
    
        jclass      (*DefineClass)(JNIEnv*, const char*, jobject, const jbyte*,
                            jsize);
        jclass      (*FindClass)(JNIEnv*, const char*);
    
        jmethodID   (*FromReflectedMethod)(JNIEnv*, jobject);
        jfieldID    (*FromReflectedField)(JNIEnv*, jobject);
        /* spec doesn't show jboolean parameter */
        jobject     (*ToReflectedMethod)(JNIEnv*, jclass, jmethodID, jboolean);
    
        jclass      (*GetSuperclass)(JNIEnv*, jclass);
        jboolean    (*IsAssignableFrom)(JNIEnv*, jclass, jclass);
    
        /* spec doesn't show jboolean parameter */
        jobject     (*ToReflectedField)(JNIEnv*, jclass, jfieldID, jboolean);
    
        jint        (*Throw)(JNIEnv*, jthrowable);
        jint        (*ThrowNew)(JNIEnv *, jclass, const char *);
        jthrowable  (*ExceptionOccurred)(JNIEnv*);
        void        (*ExceptionDescribe)(JNIEnv*);
        void        (*ExceptionClear)(JNIEnv*);
        void        (*FatalError)(JNIEnv*, const char*);
    
        jint        (*PushLocalFrame)(JNIEnv*, jint);
        jobject     (*PopLocalFrame)(JNIEnv*, jobject);
    
        jobject     (*NewGlobalRef)(JNIEnv*, jobject);
        void        (*DeleteGlobalRef)(JNIEnv*, jobject);
        void        (*DeleteLocalRef)(JNIEnv*, jobject);
        jboolean    (*IsSameObject)(JNIEnv*, jobject, jobject);
    
        jobject     (*NewLocalRef)(JNIEnv*, jobject);
        jint        (*EnsureLocalCapacity)(JNIEnv*, jint);
    
        jobject     (*AllocObject)(JNIEnv*, jclass);
        jobject     (*NewObject)(JNIEnv*, jclass, jmethodID, ...);
        jobject     (*NewObjectV)(JNIEnv*, jclass, jmethodID, va_list);
        jobject     (*NewObjectA)(JNIEnv*, jclass, jmethodID, const jvalue*);
    
        jclass      (*GetObjectClass)(JNIEnv*, jobject);
        jboolean    (*IsInstanceOf)(JNIEnv*, jobject, jclass);
        jmethodID   (*GetMethodID)(JNIEnv*, jclass, const char*, const char*);
    
        jobject     (*CallObjectMethod)(JNIEnv*, jobject, jmethodID, ...);
        jobject     (*CallObjectMethodV)(JNIEnv*, jobject, jmethodID, va_list);
        jobject     (*CallObjectMethodA)(JNIEnv*, jobject, jmethodID, const jvalue*);
        jboolean    (*CallBooleanMethod)(JNIEnv*, jobject, jmethodID, ...);
        jboolean    (*CallBooleanMethodV)(JNIEnv*, jobject, jmethodID, va_list);
        jboolean    (*CallBooleanMethodA)(JNIEnv*, jobject, jmethodID, const jvalue*);
        jbyte       (*CallByteMethod)(JNIEnv*, jobject, jmethodID, ...);
        jbyte       (*CallByteMethodV)(JNIEnv*, jobject, jmethodID, va_list);
        jbyte       (*CallByteMethodA)(JNIEnv*, jobject, jmethodID, const jvalue*);
        jchar       (*CallCharMethod)(JNIEnv*, jobject, jmethodID, ...);
        jchar       (*CallCharMethodV)(JNIEnv*, jobject, jmethodID, va_list);
        jchar       (*CallCharMethodA)(JNIEnv*, jobject, jmethodID, const jvalue*);
        jshort      (*CallShortMethod)(JNIEnv*, jobject, jmethodID, ...);
        jshort      (*CallShortMethodV)(JNIEnv*, jobject, jmethodID, va_list);
        jshort      (*CallShortMethodA)(JNIEnv*, jobject, jmethodID, const jvalue*);
        jint        (*CallIntMethod)(JNIEnv*, jobject, jmethodID, ...);
        jint        (*CallIntMethodV)(JNIEnv*, jobject, jmethodID, va_list);
        jint        (*CallIntMethodA)(JNIEnv*, jobject, jmethodID, const jvalue*);
        jlong       (*CallLongMethod)(JNIEnv*, jobject, jmethodID, ...);
        jlong       (*CallLongMethodV)(JNIEnv*, jobject, jmethodID, va_list);
        jlong       (*CallLongMethodA)(JNIEnv*, jobject, jmethodID, const jvalue*);
        jfloat      (*CallFloatMethod)(JNIEnv*, jobject, jmethodID, ...);
        jfloat      (*CallFloatMethodV)(JNIEnv*, jobject, jmethodID, va_list);
        jfloat      (*CallFloatMethodA)(JNIEnv*, jobject, jmethodID, const jvalue*);
        jdouble     (*CallDoubleMethod)(JNIEnv*, jobject, jmethodID, ...);
        jdouble     (*CallDoubleMethodV)(JNIEnv*, jobject, jmethodID, va_list);
        jdouble     (*CallDoubleMethodA)(JNIEnv*, jobject, jmethodID, const jvalue*);
        void        (*CallVoidMethod)(JNIEnv*, jobject, jmethodID, ...);
        void        (*CallVoidMethodV)(JNIEnv*, jobject, jmethodID, va_list);
        void        (*CallVoidMethodA)(JNIEnv*, jobject, jmethodID, const jvalue*);
    
        jobject     (*CallNonvirtualObjectMethod)(JNIEnv*, jobject, jclass,
                            jmethodID, ...);
        jobject     (*CallNonvirtualObjectMethodV)(JNIEnv*, jobject, jclass,
                            jmethodID, va_list);
        jobject     (*CallNonvirtualObjectMethodA)(JNIEnv*, jobject, jclass,
                            jmethodID, const jvalue*);
        jboolean    (*CallNonvirtualBooleanMethod)(JNIEnv*, jobject, jclass,
                            jmethodID, ...);
        jboolean    (*CallNonvirtualBooleanMethodV)(JNIEnv*, jobject, jclass,
                             jmethodID, va_list);
        jboolean    (*CallNonvirtualBooleanMethodA)(JNIEnv*, jobject, jclass,
                             jmethodID, const jvalue*);
        jbyte       (*CallNonvirtualByteMethod)(JNIEnv*, jobject, jclass,
                            jmethodID, ...);
        jbyte       (*CallNonvirtualByteMethodV)(JNIEnv*, jobject, jclass,
                            jmethodID, va_list);
        jbyte       (*CallNonvirtualByteMethodA)(JNIEnv*, jobject, jclass,
                            jmethodID, const jvalue*);
        jchar       (*CallNonvirtualCharMethod)(JNIEnv*, jobject, jclass,
                            jmethodID, ...);
        jchar       (*CallNonvirtualCharMethodV)(JNIEnv*, jobject, jclass,
                            jmethodID, va_list);
        jchar       (*CallNonvirtualCharMethodA)(JNIEnv*, jobject, jclass,
                            jmethodID, const jvalue*);
        jshort      (*CallNonvirtualShortMethod)(JNIEnv*, jobject, jclass,
                            jmethodID, ...);
        jshort      (*CallNonvirtualShortMethodV)(JNIEnv*, jobject, jclass,
                            jmethodID, va_list);
        jshort      (*CallNonvirtualShortMethodA)(JNIEnv*, jobject, jclass,
                            jmethodID, const jvalue*);
        jint        (*CallNonvirtualIntMethod)(JNIEnv*, jobject, jclass,
                            jmethodID, ...);
        jint        (*CallNonvirtualIntMethodV)(JNIEnv*, jobject, jclass,
                            jmethodID, va_list);
        jint        (*CallNonvirtualIntMethodA)(JNIEnv*, jobject, jclass,
                            jmethodID, const jvalue*);
        jlong       (*CallNonvirtualLongMethod)(JNIEnv*, jobject, jclass,
                            jmethodID, ...);
        jlong       (*CallNonvirtualLongMethodV)(JNIEnv*, jobject, jclass,
                            jmethodID, va_list);
        jlong       (*CallNonvirtualLongMethodA)(JNIEnv*, jobject, jclass,
                            jmethodID, const jvalue*);
        jfloat      (*CallNonvirtualFloatMethod)(JNIEnv*, jobject, jclass,
                            jmethodID, ...);
        jfloat      (*CallNonvirtualFloatMethodV)(JNIEnv*, jobject, jclass,
                            jmethodID, va_list);
        jfloat      (*CallNonvirtualFloatMethodA)(JNIEnv*, jobject, jclass,
                            jmethodID, const jvalue*);
        jdouble     (*CallNonvirtualDoubleMethod)(JNIEnv*, jobject, jclass,
                            jmethodID, ...);
        jdouble     (*CallNonvirtualDoubleMethodV)(JNIEnv*, jobject, jclass,
                            jmethodID, va_list);
        jdouble     (*CallNonvirtualDoubleMethodA)(JNIEnv*, jobject, jclass,
                            jmethodID, const jvalue*);
        void        (*CallNonvirtualVoidMethod)(JNIEnv*, jobject, jclass,
                            jmethodID, ...);
        void        (*CallNonvirtualVoidMethodV)(JNIEnv*, jobject, jclass,
                            jmethodID, va_list);
        void        (*CallNonvirtualVoidMethodA)(JNIEnv*, jobject, jclass,
                            jmethodID, const jvalue*);
    
        jfieldID    (*GetFieldID)(JNIEnv*, jclass, const char*, const char*);
    
        jobject     (*GetObjectField)(JNIEnv*, jobject, jfieldID);
        jboolean    (*GetBooleanField)(JNIEnv*, jobject, jfieldID);
        jbyte       (*GetByteField)(JNIEnv*, jobject, jfieldID);
        jchar       (*GetCharField)(JNIEnv*, jobject, jfieldID);
        jshort      (*GetShortField)(JNIEnv*, jobject, jfieldID);
        jint        (*GetIntField)(JNIEnv*, jobject, jfieldID);
        jlong       (*GetLongField)(JNIEnv*, jobject, jfieldID);
        jfloat      (*GetFloatField)(JNIEnv*, jobject, jfieldID);
        jdouble     (*GetDoubleField)(JNIEnv*, jobject, jfieldID);
    
        void        (*SetObjectField)(JNIEnv*, jobject, jfieldID, jobject);
        void        (*SetBooleanField)(JNIEnv*, jobject, jfieldID, jboolean);
        void        (*SetByteField)(JNIEnv*, jobject, jfieldID, jbyte);
        void        (*SetCharField)(JNIEnv*, jobject, jfieldID, jchar);
        void        (*SetShortField)(JNIEnv*, jobject, jfieldID, jshort);
        void        (*SetIntField)(JNIEnv*, jobject, jfieldID, jint);
        void        (*SetLongField)(JNIEnv*, jobject, jfieldID, jlong);
        void        (*SetFloatField)(JNIEnv*, jobject, jfieldID, jfloat);
        void        (*SetDoubleField)(JNIEnv*, jobject, jfieldID, jdouble);
    
        jmethodID   (*GetStaticMethodID)(JNIEnv*, jclass, const char*, const char*);
    
        jobject     (*CallStaticObjectMethod)(JNIEnv*, jclass, jmethodID, ...);
        jobject     (*CallStaticObjectMethodV)(JNIEnv*, jclass, jmethodID, va_list);
        jobject     (*CallStaticObjectMethodA)(JNIEnv*, jclass, jmethodID, const jvalue*);
        jboolean    (*CallStaticBooleanMethod)(JNIEnv*, jclass, jmethodID, ...);
        jboolean    (*CallStaticBooleanMethodV)(JNIEnv*, jclass, jmethodID,
                            va_list);
        jboolean    (*CallStaticBooleanMethodA)(JNIEnv*, jclass, jmethodID, const jvalue*);
        jbyte       (*CallStaticByteMethod)(JNIEnv*, jclass, jmethodID, ...);
        jbyte       (*CallStaticByteMethodV)(JNIEnv*, jclass, jmethodID, va_list);
        jbyte       (*CallStaticByteMethodA)(JNIEnv*, jclass, jmethodID, const jvalue*);
        jchar       (*CallStaticCharMethod)(JNIEnv*, jclass, jmethodID, ...);
        jchar       (*CallStaticCharMethodV)(JNIEnv*, jclass, jmethodID, va_list);
        jchar       (*CallStaticCharMethodA)(JNIEnv*, jclass, jmethodID, const jvalue*);
        jshort      (*CallStaticShortMethod)(JNIEnv*, jclass, jmethodID, ...);
        jshort      (*CallStaticShortMethodV)(JNIEnv*, jclass, jmethodID, va_list);
        jshort      (*CallStaticShortMethodA)(JNIEnv*, jclass, jmethodID, const jvalue*);
        jint        (*CallStaticIntMethod)(JNIEnv*, jclass, jmethodID, ...);
        jint        (*CallStaticIntMethodV)(JNIEnv*, jclass, jmethodID, va_list);
        jint        (*CallStaticIntMethodA)(JNIEnv*, jclass, jmethodID, const jvalue*);
        jlong       (*CallStaticLongMethod)(JNIEnv*, jclass, jmethodID, ...);
        jlong       (*CallStaticLongMethodV)(JNIEnv*, jclass, jmethodID, va_list);
        jlong       (*CallStaticLongMethodA)(JNIEnv*, jclass, jmethodID, const jvalue*);
        jfloat      (*CallStaticFloatMethod)(JNIEnv*, jclass, jmethodID, ...);
        jfloat      (*CallStaticFloatMethodV)(JNIEnv*, jclass, jmethodID, va_list);
        jfloat      (*CallStaticFloatMethodA)(JNIEnv*, jclass, jmethodID, const jvalue*);
        jdouble     (*CallStaticDoubleMethod)(JNIEnv*, jclass, jmethodID, ...);
        jdouble     (*CallStaticDoubleMethodV)(JNIEnv*, jclass, jmethodID, va_list);
        jdouble     (*CallStaticDoubleMethodA)(JNIEnv*, jclass, jmethodID, const jvalue*);
        void        (*CallStaticVoidMethod)(JNIEnv*, jclass, jmethodID, ...);
        void        (*CallStaticVoidMethodV)(JNIEnv*, jclass, jmethodID, va_list);
        void        (*CallStaticVoidMethodA)(JNIEnv*, jclass, jmethodID, const jvalue*);
    
        jfieldID    (*GetStaticFieldID)(JNIEnv*, jclass, const char*,
                            const char*);
    
        jobject     (*GetStaticObjectField)(JNIEnv*, jclass, jfieldID);
        jboolean    (*GetStaticBooleanField)(JNIEnv*, jclass, jfieldID);
        jbyte       (*GetStaticByteField)(JNIEnv*, jclass, jfieldID);
        jchar       (*GetStaticCharField)(JNIEnv*, jclass, jfieldID);
        jshort      (*GetStaticShortField)(JNIEnv*, jclass, jfieldID);
        jint        (*GetStaticIntField)(JNIEnv*, jclass, jfieldID);
        jlong       (*GetStaticLongField)(JNIEnv*, jclass, jfieldID);
        jfloat      (*GetStaticFloatField)(JNIEnv*, jclass, jfieldID);
        jdouble     (*GetStaticDoubleField)(JNIEnv*, jclass, jfieldID);
    
        void        (*SetStaticObjectField)(JNIEnv*, jclass, jfieldID, jobject);
        void        (*SetStaticBooleanField)(JNIEnv*, jclass, jfieldID, jboolean);
        void        (*SetStaticByteField)(JNIEnv*, jclass, jfieldID, jbyte);
        void        (*SetStaticCharField)(JNIEnv*, jclass, jfieldID, jchar);
        void        (*SetStaticShortField)(JNIEnv*, jclass, jfieldID, jshort);
        void        (*SetStaticIntField)(JNIEnv*, jclass, jfieldID, jint);
        void        (*SetStaticLongField)(JNIEnv*, jclass, jfieldID, jlong);
        void        (*SetStaticFloatField)(JNIEnv*, jclass, jfieldID, jfloat);
        void        (*SetStaticDoubleField)(JNIEnv*, jclass, jfieldID, jdouble);
    
        jstring     (*NewString)(JNIEnv*, const jchar*, jsize);
        jsize       (*GetStringLength)(JNIEnv*, jstring);
        const jchar* (*GetStringChars)(JNIEnv*, jstring, jboolean*);
        void        (*ReleaseStringChars)(JNIEnv*, jstring, const jchar*);
        jstring     (*NewStringUTF)(JNIEnv*, const char*);
        jsize       (*GetStringUTFLength)(JNIEnv*, jstring);
        /* JNI spec says this returns const jbyte*, but that's inconsistent */
        const char* (*GetStringUTFChars)(JNIEnv*, jstring, jboolean*);
        void        (*ReleaseStringUTFChars)(JNIEnv*, jstring, const char*);
        jsize       (*GetArrayLength)(JNIEnv*, jarray);
        jobjectArray (*NewObjectArray)(JNIEnv*, jsize, jclass, jobject);
        jobject     (*GetObjectArrayElement)(JNIEnv*, jobjectArray, jsize);
        void        (*SetObjectArrayElement)(JNIEnv*, jobjectArray, jsize, jobject);
    
        jbooleanArray (*NewBooleanArray)(JNIEnv*, jsize);
        jbyteArray    (*NewByteArray)(JNIEnv*, jsize);
        jcharArray    (*NewCharArray)(JNIEnv*, jsize);
        jshortArray   (*NewShortArray)(JNIEnv*, jsize);
        jintArray     (*NewIntArray)(JNIEnv*, jsize);
        jlongArray    (*NewLongArray)(JNIEnv*, jsize);
        jfloatArray   (*NewFloatArray)(JNIEnv*, jsize);
        jdoubleArray  (*NewDoubleArray)(JNIEnv*, jsize);
    
        jboolean*   (*GetBooleanArrayElements)(JNIEnv*, jbooleanArray, jboolean*);
        jbyte*      (*GetByteArrayElements)(JNIEnv*, jbyteArray, jboolean*);
        jchar*      (*GetCharArrayElements)(JNIEnv*, jcharArray, jboolean*);
        jshort*     (*GetShortArrayElements)(JNIEnv*, jshortArray, jboolean*);
        jint*       (*GetIntArrayElements)(JNIEnv*, jintArray, jboolean*);
        jlong*      (*GetLongArrayElements)(JNIEnv*, jlongArray, jboolean*);
        jfloat*     (*GetFloatArrayElements)(JNIEnv*, jfloatArray, jboolean*);
        jdouble*    (*GetDoubleArrayElements)(JNIEnv*, jdoubleArray, jboolean*);
    
        void        (*ReleaseBooleanArrayElements)(JNIEnv*, jbooleanArray,
                            jboolean*, jint);
        void        (*ReleaseByteArrayElements)(JNIEnv*, jbyteArray,
                            jbyte*, jint);
        void        (*ReleaseCharArrayElements)(JNIEnv*, jcharArray,
                            jchar*, jint);
        void        (*ReleaseShortArrayElements)(JNIEnv*, jshortArray,
                            jshort*, jint);
        void        (*ReleaseIntArrayElements)(JNIEnv*, jintArray,
                            jint*, jint);
        void        (*ReleaseLongArrayElements)(JNIEnv*, jlongArray,
                            jlong*, jint);
        void        (*ReleaseFloatArrayElements)(JNIEnv*, jfloatArray,
                            jfloat*, jint);
        void        (*ReleaseDoubleArrayElements)(JNIEnv*, jdoubleArray,
                            jdouble*, jint);
    
        void        (*GetBooleanArrayRegion)(JNIEnv*, jbooleanArray,
                            jsize, jsize, jboolean*);
        void        (*GetByteArrayRegion)(JNIEnv*, jbyteArray,
                            jsize, jsize, jbyte*);
        void        (*GetCharArrayRegion)(JNIEnv*, jcharArray,
                            jsize, jsize, jchar*);
        void        (*GetShortArrayRegion)(JNIEnv*, jshortArray,
                            jsize, jsize, jshort*);
        void        (*GetIntArrayRegion)(JNIEnv*, jintArray,
                            jsize, jsize, jint*);
        void        (*GetLongArrayRegion)(JNIEnv*, jlongArray,
                            jsize, jsize, jlong*);
        void        (*GetFloatArrayRegion)(JNIEnv*, jfloatArray,
                            jsize, jsize, jfloat*);
        void        (*GetDoubleArrayRegion)(JNIEnv*, jdoubleArray,
                            jsize, jsize, jdouble*);
    
        /* spec shows these without const; some jni.h do, some don't */
        void        (*SetBooleanArrayRegion)(JNIEnv*, jbooleanArray,
                            jsize, jsize, const jboolean*);
        void        (*SetByteArrayRegion)(JNIEnv*, jbyteArray,
                            jsize, jsize, const jbyte*);
        void        (*SetCharArrayRegion)(JNIEnv*, jcharArray,
                            jsize, jsize, const jchar*);
        void        (*SetShortArrayRegion)(JNIEnv*, jshortArray,
                            jsize, jsize, const jshort*);
        void        (*SetIntArrayRegion)(JNIEnv*, jintArray,
                            jsize, jsize, const jint*);
        void        (*SetLongArrayRegion)(JNIEnv*, jlongArray,
                            jsize, jsize, const jlong*);
        void        (*SetFloatArrayRegion)(JNIEnv*, jfloatArray,
                            jsize, jsize, const jfloat*);
        void        (*SetDoubleArrayRegion)(JNIEnv*, jdoubleArray,
                            jsize, jsize, const jdouble*);
    
        jint        (*RegisterNatives)(JNIEnv*, jclass, const JNINativeMethod*,
                            jint);
        jint        (*UnregisterNatives)(JNIEnv*, jclass);
        jint        (*MonitorEnter)(JNIEnv*, jobject);
        jint        (*MonitorExit)(JNIEnv*, jobject);
        jint        (*GetJavaVM)(JNIEnv*, JavaVM**);
    
        void        (*GetStringRegion)(JNIEnv*, jstring, jsize, jsize, jchar*);
        void        (*GetStringUTFRegion)(JNIEnv*, jstring, jsize, jsize, char*);
    
        void*       (*GetPrimitiveArrayCritical)(JNIEnv*, jarray, jboolean*);
        void        (*ReleasePrimitiveArrayCritical)(JNIEnv*, jarray, void*, jint);
    
        const jchar* (*GetStringCritical)(JNIEnv*, jstring, jboolean*);
        void        (*ReleaseStringCritical)(JNIEnv*, jstring, const jchar*);
    
        jweak       (*NewWeakGlobalRef)(JNIEnv*, jobject);
        void        (*DeleteWeakGlobalRef)(JNIEnv*, jweak);
    
        jboolean    (*ExceptionCheck)(JNIEnv*);
    
        jobject     (*NewDirectByteBuffer)(JNIEnv*, void*, jlong);
        void*       (*GetDirectBufferAddress)(JNIEnv*, jobject);
        jlong       (*GetDirectBufferCapacity)(JNIEnv*, jobject);
    
        /* added in JNI 1.6 */
        jobjectRefType (*GetObjectRefType)(JNIEnv*, jobject);
    };
 
    struct JNIInvokeInterface {
        void*       reserved0;
        void*       reserved1;
        void*       reserved2;
    
        jint        (*DestroyJavaVM)(JavaVM*);
        jint        (*AttachCurrentThread)(JavaVM*, JNIEnv**, void*);
        jint        (*DetachCurrentThread)(JavaVM*);
        jint        (*GetEnv)(JavaVM*, void**, jint);
        jint        (*AttachCurrentThreadAsDaemon)(JavaVM*, JNIEnv**, void*);
    };
 
    struct JavaVMAttachArgs {
        jint        version;    /* must be >= JNI_VERSION_1_2 */
        const char* name;       /* NULL or name of thread as modified UTF-8 str */
        jobject     group;      /* global ref of a ThreadGroup object, or NULL */
    };
    typedef struct JavaVMAttachArgs JavaVMAttachArgs;
 
    typedef struct JavaVMOption {
        const char* optionString;
        void*       extraInfo;
    } JavaVMOption;
    
    typedef struct JavaVMInitArgs {
        jint        version;    /* use JNI_VERSION_1_2 or later */
    
        jint        nOptions;
        JavaVMOption* options;
        jboolean    ignoreUnrecognized;
    } JavaVMInitArgs;
 
    static const int JNI_FALSE = 0;
    static const int JNI_TRUE = 1;
 
    static const int JNI_VERSION_1_1 = 0x00010001;
    static const int JNI_VERSION_1_2 = 0x00010002;
    static const int JNI_VERSION_1_4 = 0x00010004;
    static const int JNI_VERSION_1_6 = 0x00010006;
 
    static const int JNI_OK        = (0);         /* no error */
    static const int JNI_ERR       = (-1);        /* generic error */
    static const int JNI_EDETACHED = (-2);        /* thread detached from the VM */
    static const int JNI_EVERSION  = (-3);        /* JNI version error */
 
    static const int JNI_COMMIT    = 1;           /* copy content, do not free buffer */
    static const int JNI_ABORT     = 2;           /* free buffer w/o copying back */
 
    JNIEnv* _Z24NVThreadGetCurrentJNIEnvv();
    jobject _Z27NVEventGetPlatformAppHandlev();
]]
 
local C = ffi.C
local gta = ffi.load("GTASA")
 
local function getJNIEnv()
    return gta._Z24NVThreadGetCurrentJNIEnvv()
end
 
local function getActivity()
    return gta._Z27NVEventGetPlatformAppHandlev()
end
 
local JNI = {
    env = getJNIEnv(),
    classCache = {},
    methodCache = {},
    staticMethodCache = {},
    fieldCache = {},
    staticFieldCache = {}
}
 
function JNI:context2(runnable, capacity)
    capacity = capacity or 16
 
    self.env = getJNIEnv()
    self.env[0].PushLocalFrame(self.env, capacity)
    local result = { runnable(self) }
    self:checkForJNIException()
    self.env[0].PopLocalFrame(self.env, nil)
 
    return unpack(result)
end
 
function JNI:throwable2string(throwable)
    local message = self:callObjectMethod(throwable, "getMessage", "()Ljava/lang/String;")
    return self:to_luastring(message)
end
 
function JNI:checkForJNIException()
    if self.env[0].ExceptionCheck(self.env) == C.JNI_TRUE then
        self.env[0].ExceptionDescribe(self.env)
        self.env[0].ExceptionClear(self.env)
        error("JNI exception occurred")
    end
end
 
function JNI:callVoidMethod(object, method, signature, ...)
    local clazz = self.env[0].GetObjectClass(self.env, object)
    local methodID = self.env[0].GetMethodID(self.env, clazz, method, signature)
    self.env[0].CallVoidMethod(self.env, object, methodID, ...)
    self.env[0].DeleteLocalRef(self.env, clazz)
end
 
function JNI:callStaticVoidMethod(class, method, signature, ...)
    local clazz = self:findClass(class)
    local methodID = self.env[0].GetStaticMethodID(self.env, clazz, method, signature)
    self.env[0].CallStaticVoidMethod(self.env, clazz, methodID, ...)
end
 
function JNI:callIntMethod(object, method, signature, ...)
    local clazz = self.env[0].GetObjectClass(self.env, object)
    local methodID = self.env[0].GetMethodID(self.env, clazz, method, signature)
    local res = self.env[0].CallIntMethod(self.env, object, methodID, ...)
    self.env[0].DeleteLocalRef(self.env, clazz)
    return res
end
 
function JNI:callStaticIntMethod(class, method, signature, ...)
    local clazz = self:findClass(class)
    local methodID = self.env[0].GetStaticMethodID(self.env, clazz, method, signature)
    local res = self.env[0].CallStaticIntMethod(self.env, clazz, methodID, ...)
    return res
end
 
function JNI:callLongMethod(object, method, signature, ...)
    local clazz = self.env[0].GetObjectClass(self.env, object)
    local methodID = self.env[0].GetMethodID(self.env, clazz, method, signature)
    local res = self.env[0].CallLongMethod(self.env, object, methodID, ...)
    self.env[0].DeleteLocalRef(self.env, clazz)
    return res
end
 
function JNI:callStaticLongMethod(class, method, signature, ...)
    local clazz = self:findClass(class)
    local methodID = self.env[0].GetStaticMethodID(self.env, clazz, method, signature)
    local res = self.env[0].CallStaticLongMethod(self.env, clazz, methodID, ...)
    return res
end
 
function JNI:callBooleanMethod(object, method, signature, ...)
    local clazz = self.env[0].GetObjectClass(self.env, object)
    local methodID = self.env[0].GetMethodID(self.env, clazz, method, signature)
    local res = self.env[0].CallBooleanMethod(self.env, object, methodID, ...)
    self.env[0].DeleteLocalRef(self.env, clazz)
    return res == C.JNI_TRUE
end
 
function JNI:callStaticBooleanMethod(class, method, signature, ...)
    local clazz = self:findClass(class)
    local methodID = self.env[0].GetStaticMethodID(self.env, clazz, method, signature)
    local res = self.env[0].CallStaticBooleanMethod(self.env, clazz, methodID, ...)
    return res == C.JNI_TRUE
end
 
function JNI:callObjectMethod(object, method, signature, ...)
    local clazz = self.env[0].GetObjectClass(self.env, object)
    print("Class: " .. tostring(clazz))
    local methodID = self.env[0].GetMethodID(self.env, clazz, method, signature)
    print("MethodID: " .. tostring(methodID))
    local obj = self.env[0].CallObjectMethod(self.env, object, methodID, ...)
    print("Result: " .. tostring(obj))
    self.env[0].DeleteLocalRef(self.env, clazz)
    return obj
end
 
function JNI:callStaticObjectMethod(class, method, signature, ...)
    print("Class: " .. tostring(class))
    local clazz = self:findClass(class)
    print("Clazz: " .. tostring(clazz))
 
    local methodID = self.env[0].GetStaticMethodID(self.env, clazz, method, signature)
    print("MethodID: " .. tostring(methodID))
 
    local res = self.env[0].CallStaticObjectMethod(self.env, clazz, methodID, ...)
    print("Result: " .. tostring(res))
    return res
end
 
function JNI:getStaticObjectField(class, field, signature)
    print("Class: " .. tostring(class))
    local clazz = self:findClass(class)
    print("Clazz: " .. tostring(clazz))
    local fieldID = self.env[0].GetStaticFieldID(self.env, clazz, field, signature)
    print("FieldID: " .. tostring(fieldID))
 
    local obj = self.env[0].GetStaticObjectField(self.env, clazz, fieldID)
    return obj
end
 
function JNI:getObjectField(object, field, signature)
    local clazz = self.env[0].GetObjectClass(self.env, object)
    local fieldID = self.env[0].GetFieldID(self.env, clazz, field, signature)
    local obj = self.env[0].GetObjectField(self.env, object, fieldID)
    self.env[0].DeleteLocalRef(self.env, clazz)
    return obj
end
 
function JNI:setObjectField(object, field, signature, value)
    local clazz = self.env[0].GetObjectClass(self.env, object)
    local fieldID = self.env[0].GetFieldID(self.env, clazz, field, signature)
    self.env[0].SetObjectField(self.env, object, fieldID, value)
    self.env[0].DeleteLocalRef(self.env, clazz)
    return object
end
 
function JNI:setFloatField(object, field, signature, value)
    local clazz = self.env[0].GetObjectClass(self.env, object)
    local fieldID = self.env[0].GetFieldID(self.env, clazz, field, signature)
    self.env[0].SetFloatField(self.env, object, fieldID, value)
    self.env[0].DeleteLocalRef(self.env, clazz)
    return object
end
 
function JNI:to_luastring(javastring)
    local utf = self.env[0].GetStringUTFChars(self.env, javastring, nil)
    local luastr = ffi.string(utf, self.env[0].GetStringUTFLength(self.env, javastring))
    self.env[0].ReleaseStringUTFChars(self.env, javastring, utf)
    return luastr
end
 
function JNI:to_javastring(luastring)
    local str = self.env[0].NewStringUTF(self.env, luastring)
    return str
end
 
 
function JNI:activityClassloader()
    if self.classloader then
        return self.classloader
    end
 
    local cldr = self:callObjectMethod(getActivity(), "getClassLoader", "()Ljava/lang/ClassLoader;")
    self.classloader = self.env[0].NewGlobalRef(self.env, cldr)
    self.env[0].DeleteLocalRef(self.env, cldr)
 
    local classLoaderClass = self.env[0].FindClass(self.env, "java/lang/ClassLoader")

    self.loadClassMethodId = self.env[0].GetMethodID(
        self.env,
        classLoaderClass,
        "loadClass",
        "(Ljava/lang/String;)Ljava/lang/Class;"
    )
    return self.classloader
end
 
function JNI:findClass(class)
    if self.classCache[class] then
        return self.classCache[class]
    end
 
    local cldr = self:activityClassloader()
    local classStr = self:to_javastring(class)
    local clazz = self.env[0].CallObjectMethod(
        self.env,
        cldr,
        self.loadClassMethodId,
        classStr
    )
 
    self.classCache[class] = ffi.cast('jclass', self.env[0].NewGlobalRef(self.env, clazz))
    self.env[0].DeleteLocalRef(self.env, classStr)
    self.env[0].DeleteLocalRef(self.env, clazz)
 
    return self.classCache[class]
end
 
function JNI:showToast(message, duration)
    local duration = duration or 1
    local makeText = self:callStaticObjectMethod(
        "android/widget/Toast",
        "makeText",
        "(Landroid/content/Context;Ljava/lang/CharSequence;I)Landroid/widget/Toast;",
        getActivity(),
        self:to_javastring(message),
        duration
    )
    if makeText == nil then
        print("Call the JNI:looperPrepare before calling the showToast")
        JNI:checkForJNIException()
        return
    end
 
    self:callVoidMethod(makeText, "show", "()V")
end
 
function JNI:looperPrepare()
    local looper = self:callStaticObjectMethod("android/os/Looper", "myLooper", "()Landroid/os/Looper;")
 
    if looper == nil then
        self:callStaticVoidMethod("android/os/Looper", "prepare", "()V")
    end
end
 
return JNI end)
package.preload['lib.sandbox'] = (function (...)
local sandbox = {
	_VERSION = "kong-lua-sandbox 1.0",
	_DESCRIPTION = "A pure-lua solution for running untrusted Lua code.",
	_URL = "https://github.com/kong/kong-lua-sandbox",
	_LICENSE = [[
      MIT LICENSE
  
      Copyright (c) 2021 Kong Inc
  
      Permission is hereby granted, free of charge, to any person obtaining a
      copy of this software and associated documentation files (the
      "Software"), to deal in the Software without restriction, including
      without limitation the rights to use, copy, modify, merge, publish,
      distribute, sublicense, and/or sell copies of the Software, and to
      permit persons to whom the Software is furnished to do so, subject to
      the following conditions:
  
      The above copyright notice and this permission notice shall be included
      in all copies or substantial portions of the Software.
  
      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
      OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
      MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
      IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
      CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
      TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
      SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    ]],
}

-- quotas don't work in LuaJIT since debug.sethook works differently there
local quota_supported = type(_G.jit) == "nil"
sandbox.quota_supported = quota_supported

-- PUC-Rio Lua 5.1 does not support deactivation of bytecode
local bytecode_blocked = _ENV or type(_G.jit) == "table"
sandbox.bytecode_blocked = bytecode_blocked

-- The base environment is merged with the given env option (or an empty table, if no env provided)
--
local BASE_ENV = {};

-- List of unsafe packages/functions:
--
-- * string.rep: can be used to allocate millions of bytes in 1 operation
-- * {set|get}metatable: can be used to modify the metatable of global objects (strings, integers)
-- * collectgarbage: can affect performance of other systems
-- * dofile: can access the server filesystem
-- * _G: It has access to everything. It can be mocked to other things though.
-- * load{file|string}: All unsafe because they can grant acces to global env
-- * raw{get|set|equal}: Potentially unsafe
-- * module|require|module: Can modify the host settings
-- * string.dump: Can display confidential server info (implementation of functions)
-- * math.randomseed: Can affect the host sytem
-- * io.*, os.*: Most stuff there is unsafe, see below for exceptions

-- Safe packages/functions below
([[
  
  _VERSION assert error    ipairs   next pairs
  pcall    select tonumber tostring type unpack xpcall
  
  coroutine.create coroutine.resume coroutine.running coroutine.status
  coroutine.wrap   coroutine.yield
  
  math.abs   math.acos math.asin  math.atan math.atan2 math.ceil
  math.cos   math.cosh math.deg   math.exp  math.fmod  math.floor
  math.frexp math.huge math.ldexp math.log  math.log10 math.max
  math.min   math.modf math.pi    math.pow  math.rad   math.random
  math.sin   math.sinh math.sqrt  math.tan  math.tanh
  
  os.clock os.difftime os.time
  
  string.byte string.char  string.find  string.format string.gmatch
  string.gsub string.len   string.lower string.match  string.reverse
  string.sub  string.upper
  
  table.insert table.maxn table.remove table.sort
  
  ]]):gsub("%S+", function(id)
	local module, method = id:match("([^%.]+)%.([^%.]+)")
	if module then
		BASE_ENV[module] = BASE_ENV[module] or {}
		BASE_ENV[module][method] = _G[module][method]
	else
		BASE_ENV[id] = _G[id]
	end
end)

local function protect_module(module, module_name)
	return setmetatable({}, {
		__index = module,
		__newindex = function(_, attr_name, _)
			error("Can not modify " .. module_name .. "." .. attr_name .. ". Protected by the sandbox.")
		end,
	})
end

("coroutine math os string table"):gsub("%S+", function(module_name)
	BASE_ENV[module_name] = protect_module(BASE_ENV[module_name], module_name)
end)

-- auxiliary functions/variables

local string_rep = string.rep

local function sethook(f, key, quota)
	if type(debug) ~= "table" or type(debug.sethook) ~= "function" then
		return
	end
	debug.sethook(f, key, quota)
end

local function cleanup()
	sethook()
	string.rep = string_rep -- luacheck: no global
end

-- Public interface: sandbox.protect
table.pack = table.pack or function(...)
    return {n = select("#", ...), ...}
end
table.unpack = table.unpack or unpack
function sandbox.protect(code, options)
	options = options or {}

	local quota = false
	if options.quota and not quota_supported then
		error("options.quota is not supported on this environment (usually LuaJIT). Please unset options.quota")
	end
	if options.quota ~= false then
		quota = options.quota or 500000
	end

	assert(type(code) == "string", "expected a string")

	local passed_env = options.env or {}
	local env = {}
	for k, v in pairs(BASE_ENV) do
		local pv = passed_env[k]
		if pv ~= nil then
			env[k] = pv
		else
			env[k] = v
		end
	end
	setmetatable(env, {
		__index = options.env,
	})
	env._G = env

	local f
	if bytecode_blocked then
		f = assert(load(code, nil, "t", env))
	else
		f = assert(loadstring(code))
		setfenv(f, env)
	end

	return function(...)
		if quota and quota_supported then
			local timeout = function()
				cleanup()
				error("Quota exceeded: " .. tostring(quota))
			end
			sethook(timeout, "", quota)
		end

		string.rep = nil -- luacheck: no global

		local t = table.pack(pcall(f, ...))

		cleanup()

		if not t[1] then
			error(t[2])
		end

		return table.unpack(t, 2, t.n)
	end
end

-- Public interface: sandbox.run
function sandbox.run(code, options, ...)
	return sandbox.protect(code, options)(...)
end

-- make sandbox(f) == sandbox.protect(f)
setmetatable(sandbox, {
	__call = function(_, code, o)
		return sandbox.protect(code, o)
	end,
})

return sandbox
 end)
package.preload['src.util'] = (function (...)
local util = {}

function util.isEmpty(str)
	return str == nil or str == ""
end

function util.merge(...)
	local mergedTable = {}
	local args = { ... }
	for _, tbl in ipairs(args) do
		for k, v in pairs(tbl) do
			if type(v) == "table" and type(mergedTable[k]) == "table" then
				mergedTable[k] = util.merge(mergedTable[k], v)
			else
				mergedTable[k] = v
			end
		end
	end
	return mergedTable
end

function util.deepcopy(o, seen)
	seen = seen or {}
	if o == nil then
		return nil
	end
	if seen[o] then
		return seen[o]
	end

	local no
	if type(o) == "table" then
		no = {}
		seen[o] = no

		for k, v in next, o, nil do
			no[util.deepcopy(k, seen)] = util.deepcopy(v, seen)
		end
		setmetatable(no, util.deepcopy(getmetatable(o), seen))
	else -- number, string, boolean, etc
		no = o
	end
	return no
end

if MONET_VERSION then
	local ffi = require('ffi')
	local gta = ffi.load('GTASA')
	ffi.cdef[[
		void _Z12AND_OpenLinkPKc(const char* link);
	]]
end

function util.openLink(link)
	if MONET_VERSION then
    	gta._Z12AND_OpenLinkPKc(link)
	else
		os.execute("explorer " .. link)
	end
end

function util.find_in_tables(key, ...)
	for _, tbl in ipairs({ ... }) do
		if tbl[key] ~= nil then
			return tbl[key]
		end
	end
	return nil
end

function util.getNearestPedByPed(hndlPed, radius)
	minDist, closestHandle = nil, nil
	if doesCharExist(hndlPed) then -- проверяем, существует ли Handle
		local tX, tY, tZ = getCharCoordinates(hndlPed)
		for k, v in ipairs(getAllChars()) do
			if v ~= hndlPed then
				local x, y, z = getCharCoordinates(v)
				local dist = getDistanceBetweenCoords3d(x, y, z, tX, tY, tZ)
				if (not radius or dist < radius) and (not minDist or dist < minDist) then
					minDist, closestHandle = dist, v
				end
			end
		end
		return closestHandle
	end
end

function util.GetNearestCarByPed(HndlPed, radius, minPlayerNear)
    if doesCharExist(HndlPed) then -- проверяем, существует ли Handle
        local tableArr = {}
        local countPlayers = 0
        local posXpl, posYpl = getCharCoordinates(HndlPed)
        for _,car in pairs(getAllVehicles()) do -- перебираем все Handle машин в зоне стрима
            if getDriverOfCar(car) ~= HndlPed then -- проверяем не является ли водителем этой машины HndlPed
                local posX, posY, posZ = getCarCoordinates(car) -- получаем координаты машины
                for _,player in pairs(getAllChars()) do
                    if player ~= HndlPed then
                        local playerid = select(2, sampGetPlayerIdByCharHandle(player)) -- получаем ID игрока
                        if playerid and not sampIsPlayerNpc(playerid) and playerid ~= -1 then -- проверяем не NPC ли этот игрок
                            local x,y,z = getCharCoordinates(player)
                            if getDistanceBetweenCoords2d(x, y, posX, posY) < 3 then countPlayers = countPlayers + 1 end
                        end
                    end
                end
                local distBetween2d = getDistanceBetweenCoords2d(posXpl, posYpl, posX, posY)
                if minPlayerNear ~= false then
                    if tonumber(minPlayerNear) >= countPlayers then
                        table.insert(tableArr, {distBetween2d, car, posX, posY, posZ, countPlayers})
                    end
                else table.insert(tableArr, {distBetween2d, car, posX, posY, posZ, countPlayers}) end
                countPlayers = 0
            end
        end
        if #tableArr > 0 then -- если в таблице есть данные, то...
            table.sort(tableArr, function(a, b) return (a[1] < b[1]) end) -- сортируем 1-ое значение в каждом массиве от меньшего к большому.
            if radius ~= false then -- если функция проверки на радиус включена, то..
                if tableArr[1][1] <= tonumber(radius) then  -- если дистанция меньше или равна заданному радиусу, то ..
                    return true, tableArr[1][2], tableArr[1][1], tableArr[1][3], tableArr[1][4], tableArr[1][5], tableArr[1][6] -- возвращаем значения
                end
            else return true, tableArr[1][2], tableArr[1][1], tableArr[1][3], tableArr[1][4], tableArr[1][5], tableArr[1][6] end -- иначе, возвращаем данные
        end
    end
    return false
end

function util.TranslateNick(name)
	if name:match("%a+") then
		for k, v in pairs({
			["ph"] = "ф",
			["Ph"] = "Ф",
			["Ch"] = "Ч",
			["ch"] = "ч",
			["Th"] = "Т",
			["th"] = "т",
			["Sh"] = "Ш",
			["sh"] = "ш",
			["ea"] = "и",
			["Ae"] = "Э",
			["ae"] = "э",
			["size"] = "сайз",
			["Jj"] = "Джейджей",
			["Whi"] = "Вай",
			["lack"] = "лэк",
			["whi"] = "вай",
			["Ck"] = "К",
			["ck"] = "к",
			["Kh"] = "Х",
			["kh"] = "х",
			["hn"] = "н",
			["Hen"] = "Ген",
			["Zh"] = "Ж",
			["zh"] = "ж",
			["Yu"] = "Ю",
			["yu"] = "ю",
			["Yo"] = "Ё",
			["yo"] = "ё",
			["Cz"] = "Ц",
			["cz"] = "ц",
			["ia"] = "я",
			["ea"] = "и",
			["Ya"] = "Я",
			["ya"] = "я",
			["ove"] = "ав",
			["ay"] = "эй",
			["rise"] = "райз",
			["oo"] = "у",
			["Oo"] = "У",
			["Ee"] = "И",
			["ee"] = "и",
			["Un"] = "Ан",
			["un"] = "ан",
			["Ci"] = "Ци",
			["ci"] = "ци",
			["yse"] = "уз",
			["cate"] = "кейт",
			["eow"] = "яу",
			["rown"] = "раун",
			["yev"] = "уев",
			["Babe"] = "Бэйби",
			["Jason"] = "Джейсон",
			["liy"] = "лий",
			["ane"] = "ейн",
			["ame"] = "ейм",
		}) do
			name = name:gsub(k, v)
		end
		for k, v in pairs({
			["B"] = "Б",
			["Z"] = "З",
			["T"] = "Т",
			["Y"] = "Й",
			["P"] = "П",
			["J"] = "Дж",
			["X"] = "Кс",
			["G"] = "Г",
			["V"] = "В",
			["H"] = "Х",
			["N"] = "Н",
			["E"] = "Е",
			["I"] = "И",
			["D"] = "Д",
			["O"] = "О",
			["K"] = "К",
			["F"] = "Ф",
			["y`"] = "ы",
			["e`"] = "э",
			["A"] = "А",
			["C"] = "К",
			["L"] = "Л",
			["M"] = "М",
			["W"] = "В",
			["Q"] = "К",
			["U"] = "А",
			["R"] = "Р",
			["S"] = "С",
			["zm"] = "зьм",
			["h"] = "х",
			["q"] = "к",
			["y"] = "и",
			["a"] = "а",
			["w"] = "в",
			["b"] = "б",
			["v"] = "в",
			["g"] = "г",
			["d"] = "д",
			["e"] = "е",
			["z"] = "з",
			["i"] = "и",
			["j"] = "ж",
			["k"] = "к",
			["l"] = "л",
			["m"] = "м",
			["n"] = "н",
			["o"] = "о",
			["p"] = "п",
			["r"] = "р",
			["s"] = "с",
			["t"] = "т",
			["u"] = "у",
			["f"] = "ф",
			["x"] = "x",
			["c"] = "к",
			["``"] = "ъ",
			["`"] = "ь",
			["_"] = " ",
		}) do
			name = name:gsub(k, v)
		end
		return name
	end
	return name
end

function util.tblContainsFieldValue(tbl, field, value)
	for k, v in pairs(tbl) do
		if v[field] == value then
			return true
		end
	end
	return false
end


util.arzcars = {
	--[ID CAR] = 'NAME CAR'
	--STANDART CAR
	[400] = "Landstalker",
	[401] = "Bravura",
	[402] = "Buffalo",
	[403] = "Linerunner",
	[404] = "Perenniel",
	[405] = "Sentinel",
	[406] = "Dumper",
	[407] = "Firetruck",
	[408] = "Trashmaster",
	[409] = "Stretch",
	[410] = "Manana",
	[411] = "Infernus",
	[412] = "Voodoo",
	[413] = "Pony",
	[414] = "Mule",
	[415] = "Cheetah",
	[416] = "Ambulance",
	[417] = "Leviathan",
	[418] = "Moonbeam",
	[419] = "Esperanto",
	[420] = "Taxi",
	[421] = "Washington",
	[422] = "Bobcat",
	[423] = "Mr Whoopee",
	[424] = "BF Injection",
	[425] = "Hunter",
	[426] = "Premier",
	[427] = "Enforcer",
	[428] = "Securicar",
	[429] = "Banshee",
	[430] = "Predator",
	[431] = "Bus",
	[432] = "Rhino",
	[433] = "Barracks",
	[434] = "Hotknife",
	[435] = "Article Trailer",
	[436] = "Previon",
	[437] = "Coach",
	[438] = "Cabbie",
	[439] = "Stallion",
	[440] = "Rumpo",
	[441] = "RC Bandit",
	[442] = "Romero",
	[443] = "Packer",
	[444] = "Monster",
	[445] = "Admiral",
	[446] = "Squallo",
	[447] = "Seasparrow",
	[448] = "Pizzaboy",
	[449] = "Tram",
	[450] = "Article Trailer 2",
	[451] = "Turismo",
	[452] = "Speeder",
	[453] = "Reefer",
	[454] = "Tropic",
	[455] = "Flatbed",
	[456] = "Yankee",
	[457] = "Caddy",
	[458] = "Solair",
	[459] = "Berkley's RC",
	[460] = "Skimmer",
	[461] = "PCJ-600",
	[462] = "Faggio",
	[463] = "Freeway",
	[464] = "RC Baron",
	[465] = "RC Raider",
	[466] = "Glendale",
	[467] = "Oceanic",
	[468] = "Sanchez",
	[469] = "Sparrow",
	[470] = "Patriot",
	[471] = "Quad",
	[472] = "Coastguard",
	[473] = "Dinghy",
	[474] = "Hermes",
	[475] = "Sabre",
	[476] = "Rustler",
	[477] = "ZR-350",
	[478] = "Walton",
	[479] = "Regina",
	[480] = "Comet",
	[481] = "BMX",
	[482] = "Burrito",
	[483] = "Camper",
	[484] = "Marquis",
	[485] = "Baggage",
	[486] = "Dozer",
	[487] = "Maverick",
	[488] = "SAN News Maverick",
	[489] = "Rancher",
	[490] = "FBI Rancher",
	[491] = "Virgo",
	[492] = "Greenwood",
	[493] = "Jetmax",
	[494] = "Hotring Racer",
	[495] = "Sandking",
	[496] = "Blista Compact",
	[497] = "Police Maverick",
	[498] = "Boxville",
	[499] = "Benson",
	[500] = "Mesa",
	[501] = "RC Goblin",
	[502] = "Hotring Racer A",
	[503] = "Hotring Racer B",
	[504] = "Bloodring Banger",
	[505] = "Rancher",
	[506] = "Super GT",
	[507] = "Elegant",
	[508] = "Journey",
	[509] = "Bike",
	[510] = "Mountain Bike",
	[511] = "Beagle",
	[512] = "Cropduster",
	[513] = "Stuntplane",
	[514] = "Tanker",
	[515] = "Roadtrain",
	[516] = "Nebula",
	[517] = "Majestic",
	[518] = "Buccaneer",
	[519] = "Shamal",
	[520] = "Hydra",
	[521] = "FCR-900",
	[522] = "NRG-500",
	[523] = "HPV1000",
	[524] = "Cement Truck",
	[525] = "Towtruck",
	[526] = "Fortune",
	[527] = "Cadrona",
	[528] = "FBI Truck",
	[529] = "Willard",
	[530] = "Forklift",
	[531] = "Tractor",
	[532] = "Combine Harvester",
	[533] = "Feltzer",
	[534] = "Remington",
	[535] = "Slamvan",
	[536] = "Blade",
	[537] = "Freight (Train)",
	[538] = "Brownstreak (Train)",
	[539] = "Vortex",
	[540] = "Vincent",
	[541] = "Bullet",
	[542] = "Clover",
	[543] = "Sadler",
	[544] = "Firetruck LA",
	[545] = "Hustler",
	[546] = "Intruder",
	[547] = "Primo",
	[548] = "Cargobob",
	[549] = "Tampa",
	[550] = "Sunrise",
	[551] = "Merit",
	[552] = "Utility Van",
	[553] = "Nevada",
	[554] = "Yosemite",
	[555] = "Windsor",
	[556] = "Monster A",
	[557] = "Monster B",
	[558] = "Uranus",
	[559] = "Jester",
	[560] = "Sultan",
	[561] = "Stratum",
	[562] = "Elegy",
	[563] = "Raindance",
	[564] = "RC Tiger",
	[565] = "Flash",
	[566] = "Tahoma",
	[567] = "Savanna",
	[568] = "Bandito",
	[569] = "Freight Flat Trailer",
	[570] = "Streak Trailer",
	[571] = "Kart",
	[572] = "Mower",
	[573] = "Dune",
	[574] = "Sweeper",
	[575] = "Broadway",
	[576] = "Tornado",
	[577] = "AT400",
	[578] = "DFT-30",
	[579] = "Huntley",
	[580] = "Stafford",
	[581] = "BF-400",
	[582] = "Newsvan",
	[583] = "Tug",
	[584] = "Petrol Trailer",
	[585] = "Emperor",
	[586] = "Wayfarer",
	[587] = "Euros",
	[588] = "Hotdog",
	[589] = "Club",
	[590] = "Freight Box Trailer",
	[591] = "Article Trailer 3",
	[592] = "Andromada",
	[593] = "Dodo",
	[594] = "RC Cam",
	[595] = "Launch",
	[596] = "Police Car (LSPD)",
	[597] = "Police Car (SFPD)",
	[598] = "Police Car (LVPD)",
	[599] = "Police Ranger",
	[600] = "Picador",
	[601] = "S.W.A.T.",
	[602] = "Alpha",
	[603] = "Phoenix",
	[604] = "Glendale Shit",
	[605] = "Sadler Shit",
	[606] = "Baggage Trailer A",
	[607] = "Baggage Trailer B",
	[608] = "Tug Stairs Trailer",
	[609] = "Boxville",
	[610] = "Farm Trailer",
	[611] = "Utility Trailer",
	--CUSTOM CARS (ARIZONA)
	[612] = "Ferrari 612 Scaglietti GTS",
	[613] = "Mercedes-Benz G63 AMG",
	[614] = "Audi RS6",
	[662] = "BMW X5",
	[663] = "Chevrolet Corvette",
	[665] = "Chevrolet Cruze",
	[666] = "Lexus LX",
	[667] = "Porsche 911",
	[668] = "Porsche Cayenne",
	[699] = "Bentley Continental GT",
	[793] = "BMW M8",
	[794] = "Mercedes-Benz E63 AMG",
	[909] = "Mercedes-Benz S63 AMG",
	[965] = "Volkswagen Touareg",
	[1194] = "Lamborghini Urus",
	[1195] = "Audi R8",
	[1196] = "Dodge Challenger",
	[1197] = "Acura NSX",
	[1198] = "Volvo V60",
	[1199] = "Range Rover",
	[1200] = "Honda Civic Type R",
	[1201] = "Lexus IS",
	[1202] = "Ford Mustang",
	[1203] = "Volvo XC90",
	[1204] = "Jaguar F-PACE",
	[1205] = "Kia Optima",
	[3155] = "BMW Z4",
	[3156] = "Lamborghini Aventador SVJ",
	[3157] = "BMW X5 M",
	[3158] = "Nissan GT-R R34",
	[3194] = "Ducati Diavel",
	[3195] = "Ducati Monster",
	[3196] = "Ducati Monster Naked",
	[3197] = "Kawasaki Ninja ZX-10RR",
	[3198] = "Kawasaki W800",
	[3199] = "BMW S1000RR",
	[3200] = "Volkswagen Beetle",
	[3201] = "Bugatti Divo",
	[3202] = "Bugatti Chiron",
	[3203] = "Fiat 500",
	[3204] = "Mercedes-Benz GLS 2020",
	[3205] = "Huntley S",
	[3206] = "Lamborghini Sesto Elemento",
	[3207] = "Land Rover Range Rover Sport",
	[3208] = "BMW 530i",
	[3209] = "Mercedes-Benz S-Class (W221)",
	[3210] = "Tesla Model X",
	[3211] = "Nissan Leaf",
	[3212] = "Nissan Silvia",
	[3213] = "Bravado Banshee 900R",
	[3215] = "Benefactor Schafter V12 (Armored)",
	[3216] = "Hyundai Sonata",
	[3217] = "BMW 7 Series (E38)",
	[3218] = "Mercedes-Benz E55 AMG",
	[3219] = "Mercedes-Benz 500E",
	[3220] = "Dewbauchee Rapid GT",
	[3222] = "Pegassi Tempesta",
	[3223] = "Lexus RX",
	[3224] = "Truffade Nero Custom",
	[3232] = "Infiniti Q50",
	[3233] = "Lexus RX 350",
	[3234] = "Kia Sportage",
	[3235] = "Volkswagen Golf GTI",
	[3236] = "Audi R8 Coupe V10 plus",
	[3237] = "Toyota Camry",
	[3238] = "Toyota Camry",
	[3239] = "BMW M5 E60",
	[3240] = "BMW M5 F90",
	[3245] = "Maybach",
	[3247] = "Mercedes-Benz AMG GT",
	[3248] = "Porsche Panamera",
	[3251] = "Volkswagen Passat",
	[3254] = "Chevrolet Corvette 1980",
	[3266] = "Dodge SRT",
	[3348] = "Ford Mustang Shelby GT500",
	[3974] = "Aston Martin DB5",
	[4542] = "BMW M3 GTR",
	[4543] = "Chevrolet Camaro SS",
	[4544] = "Mazda RX-7",
	[4545] = "Mazda RX-8",
	[4546] = "Mitsubishi Eclipse",
	[4547] = "Ford Mustang old",
	[4548] = "Nissan 350Z",
	[4774] = "BMW 760Li",
	[4775] = "Aston Martin One-77",
	[4776] = "Bentley Bacalar",
	[4777] = "Bentley Bentayga",
	[4778] = "BMW M4 Competition",
	[4779] = "BMW i8",
	[4780] = "Koenigsegg CCXR Trevita",
	[4781] = "Integrity IH 35",
	[4782] = "BMW M3 G20",
	[4783] = "Mercedes-Benz S500 W223",
	[4784] = "Rimac C_Two",
	[4785] = "Ferrari J50",
	[4786] = "Mercedes-Benz SLR McLaren",
	[4787] = "Subaru BRZ",
	[4788] = "Subaru Crosstrek",
	[4789] = "Porsche Taycan",
	[4790] = "Tesla Roadster",
	[4791] = "UAZ Patriot",
	[4792] = "GAZ Volga",
	[4793] = "Mercedes-Benz X-Class",
	[4794] = "Jaguar XFR-R 2012",
	[4795] = "Rolls-Royce Shuttle",
	[4796] = "Dodge Viper",
	[4797] = "Chrysler Crossfire SRT6",
	[4798] = "Ford Expedition",
	[4799] = "Ford F-150",
	[4800] = "DeLorean DMC-12",
	[4801] = "Speedophile Seashark",
	[4802] = "Grotti Cheetah Classic",
	[4803] = "Ferrari FXX K",
	[6604] = "Audi A6",
	[6605] = "Audi Q7",
	[6606] = "BMW M6",
	[6607] = "BMW M6",
	[6608] = "Mercedes-Benz CLA 45 AMG",
	[6609] = "Mercedes-Benz CLS",
	[6610] = "Haval H2",
	[6611] = "Toyota Land Cruiser 200",
	[6612] = "Lincoln Continental",
	[6613] = "Porsche Macan",
	[6614] = "Daewoo Matiz",
	[6615] = "Mercedes-Benz G63 AMG 6x6",
	[6616] = "Mercedes-Benz E63 AMG",
	[6617] = "Monster Truck 1",
	[6618] = "Monster Truck 2",
	[6619] = "Monster Truck 3",
	[6620] = "Monster Truck 4",
	[6621] = "Toyota Land Cruiser Prado",
	[6622] = "Toyota RAV4",
	[6623] = "Toyota Supra MK4",
	[6624] = "UAZ 469",
	[6625] = "Volvo XC90",
	[12713] = "Mercedes-Benz SLS AMG GT3",
	[12714] = "Renault Laguna",
	[12715] = "Mercedes-Benz CLS 63 AMG",
	[12716] = "Audi RS5",
	[12717] = "Cadillac Escalade ESV",
	[12718] = "Tesla Cybertruck",
	[12719] = "Tesla Model C",
	[12720] = "Ford GT",
	[12721] = "Dodge Viper",
	[12722] = "Volkswagen Polo",
	[12723] = "Mitsubishi Lancer Evolution X",
	[12724] = "Audi TT RS",
	[12725] = "Mercedes-Benz Actros",
	[12726] = "Holden Commodore (VF) SSV Redline",
	[12727] = "BMW 435i",
	[12728] = "Cadillac Escalade GMT900",
	[12729] = "Toyota Chaser Tourer V",
	[12730] = "Dacia Duster",
	[12731] = "Mitsubishi Lancer Evolution X",
	[12732] = "Chevrolet Impala 1964",
	[12733] = "Chevrolet Impala 1967",
	[12734] = "Kenworth T680",
	[12735] = "Kenworth W900L",
	[12736] = "McLaren MP4-12C",
	[12737] = "Ford Mustang Mach 1",
	[12738] = "Rolls-Royce Phantom",
	[12739] = "Chevrolet Silverado Pickup",
	[12740] = "Volvo VNL 780",
	[12741] = "Subaru Impreza WRX STI",
	[12742] = "Sherp ATV",
	[12743] = "ZIL-130",
	[14119] = "Audi A6 Avant",
	[14120] = "Dodge Challenger SRT Demon",
	[14121] = "Kia Stinger GT",
	[14122] = "Lada Priora",
	[14123] = "Toyota RAV4 2016",
	[14124] = "Nissan GT-R Nismo",
	[14767] = "Aston Martin One-77",
	[14768] = "Aston Martin Valkyrie",
	[14769] = "Chevrolet Aveo",
	[14857] = "Volkswagen Buggy",
	[14884] = "Volkswagen Buggy",
	[14899] = "Dacia Duster",
	[14904] = "Chevrolet Monza",
	[14905] = "Mercedes-Benz G63 AMG 6x6",
	[14906] = "Hot Wheels Twin Mill",
	[14907] = "Hummer HX Concept",
	[14908] = "Ferrari LaFerrari",
	[14909] = "BMW M5 Competition",
	[14910] = "Lada Priora",
	[14911] = "QuaDra Q2",
	[14912] = "Mercedes-Benz GLE 450 AMG Coupe",
	[14913] = "Vision GT",
	[14914] = "Mountain Bike",
	[14915] = "Mountain Bike 2",
	[14916] = "MTB",
	[14917] = "Scorcher",
	[14918] = "Bus",
	[14919] = "Bus 2",
	[15085] = "Dodge Charger SRT Hellcat",
	[15098] = "BMW M1",
	[15099] = "Lamborghini Countach",
	[15100] = "Nagasaki Carbon RS",
	[15101] = "Koenigsegg Gemera",
	[15102] = "Kia K7",
	[15103] = "Grotti Toro",
	[15104] = "Lexus LX 600",
	[15105] = "Nissan Qashqai",
	[15106] = "Grotti Itali RSX",
	[15107] = "Volkswagen Scirocco",
	[15108] = "Benefactor Schlagen GT",
	[15109] = "Toyota GR Yaris",
	[15110] = "Wellcraft Scarab",
	[15111] = "Pegassi Yacht",
	[15112] = "Speedophile Seashark",
	[15113] = "Mercedes-AMG A 45",
	[15114] = "Toyota AE86",
	[15115] = "Land Rover Defender",
	[15116] = "Dewbauchee Vagner",
	[15117] = "Mazda 6",
	[15118] = "Audi R8 Spyder",
	[15119] = "Hyundai Santa Fe",
	[15295] = "Range Rover Velar",
	[15326] = "Mercedes-Benz Actros 1620",
	[15327] = "Topfun Van",
	[15328] = "Mule",
	[15329] = "Luxor Deluxe",
	[15330] = "Nimbus",
	[15331] = "Vestra",
	[15332] = "Mercedes-Benz Arocs",
	[15333] = "Iveco Stralis",
	[15334] = "MAN TGS",
	[15335] = "Volvo FH16",
	[15416] = "Ambulance",
	[15417] = "Banshee",
	[15418] = "Benson",
	[15419] = "Bloodring Banger",
	[15420] = "Coach",
	[15421] = "Cabbie",
	[15422] = "Police Car (VCPD)",
	[15423] = "Deluxo",
	[15424] = "FBI Rancher",
	[15425] = "Flatbed",
	[15426] = "Idaho",
	[15427] = "Infernus",
	[15428] = "Love Fist",
	[15429] = "Patriot",
	[15430] = "Pizza Boy",
	[15431] = "Securicar",
	[15432] = "Sentinel",
	[15433] = "Stinger",
	[15434] = "Stretch",
	[15435] = "Taxi",
	[15436] = "Trashmaster",
	[15485] = "Angel",
	[15486] = "BF Injection",
	[15487] = "Blista Compact",
	[15488] = "Burrito",
	[15489] = "Police Car(VCPD)",
	[15490] = "Hotring Racer",
	[15491] = "Sabre",
	[15492] = "Sanchez",
	[15493] = "Ambulance",
	[15494] = "Tesla Model S",
	[15495] = "BMW iX",
	[15496] = "Mercedes-Benz EQC",
	[15497] = "Audi e-tron",
	[15498] = "Jaguar I-PACE",
	[15499] = "Polestar 2",
	[15500] = "Polestar 2",
	[15501] = "Renault Twizy",
	[15502] = "Polestar 1",
	[15720] = "Artega GTs",
	[15721] = "Mercedes-Benz GLE",
	[15722] = "Tesla Model 3",
	[15723] = "Lamborghini Murci?lago",
	[15724] = "Hummer H2",
	[15725] = "JMC Boarding",
	[15626] = "Mercedes-Benz G-Class G 63 AMG",
	[15627] = "BMW 7 Series",
	[15628] = "Mercedes-Benz V-Class",
	[15629] = "Mercedes-Benz C-Class",
	[15630] = "Mercedes-Benz C-Class C 63 AMG",
	[15631] = "Audi RS7 Sportback",
	[15746] = "Mazda RX-7",
	[15747] = "BMW X6",
	[15748] = "Jeep Gladiator",
	[15749] = "BMW M8",
	[15750] = "Volkswagen Touareg",
	[15751] = "Land Rover Defender",
	[15752] = "Mercedes-Benz S-Class S 63 AMG",
	[15858] = "Mercedes-Benz C-Class C 63 AMG",
	[15859] = "BMW M5 F10",
	[15860] = "BMW 3 Series E30",
	[15861] = "Volkswagen Transporter",
	[15862] = "Mercedes-Benz Vito",
	[15863] = "Opel Vivaro",
	[15882] = "Boosted Board Skateboard",
	[15883] = "Surfboard",
	[15902] = "Audi 80",
	[15903] = "Mercedes-Benz C-Class C 63 AMG Coupe",
	[15904] = "BMW 5 Series E34",
	[15905] = "Mercedes-Benz E-Class E 63 AMG Wagon",
	[15906] = "BMW X5 M F85",
	[15907] = "Lamborghini Gallardo",
	[15908] = "Mercedes-Benz GLE",
	[15909] = "BMW M8 (Old Model)",
	[15910] = "Renault Sport Formula One Team R.S.18",
}

util.VehicleColoursRussianTable = {
	[0] = "Черный",
	[1] = "Серебристый",
	[2] = "Синий",
	[3] = "Красный",
	[4] = "Темно-зеленый",
	[5] = "Фиолетовый",
	[6] = "Оранжевый",
	[7] = "Светло-синий",
	[8] = "Светло-зеленый",
	[9] = "Серый",
	[10] = "Темно-синий",
	[11] = "Серый",
	[12] = "Синий",
	[13] = "Серый",
	[14] = "Светло-серый",
	[15] = "Светло-бежевый",
	[16] = "Темно-зеленый",
	[17] = "Бордовый",
	[18] = "Темно-бордовый",
	[19] = "Коричневый",
	[20] = "Темно-синий",
	[21] = "Темно-серый",
	[22] = "Темно-бордовый",
	[23] = "Коричневый",
	[24] = "Серый",
	[25] = "Темно-серый",
	[26] = "Светло-серый",
	[27] = "Серый",
	[28] = "Темно-синий",
	[29] = "Коричневый",
	[30] = "Темно-бордовый",
	[31] = "Темно-коричневый",
	[32] = "Синий",
	[33] = "Серый",
	[34] = "Темно-серый",
	[35] = "Серый",
	[36] = "Темно-серый",
	[37] = "Серый",
	[38] = "Светло-коричневый",
	[39] = "Серый",
	[40] = "Темно-бордовый",
	[41] = "Серый",
	[42] = "Темно-бордовый",
	[43] = "Темно-коричневый",
	[44] = "Темно-зеленый",
	[45] = "Темно-бордовый",
	[46] = "Бежевый",
	[47] = "Серый",
	[48] = "Коричневый",
	[49] = "Светло-серый",
	[50] = "Серый",
	[51] = "Темно-зеленый",
	[52] = "Серый",
	[53] = "Темно-синий",
	[54] = "Темно-фиолетовый",
	[55] = "Серый",
	[56] = "Светло-коричневый",
	[57] = "Бежевый",
	[58] = "Темно-бордовый",
	[59] = "Темно-синий",
	[60] = "Светло-серый",
	[61] = "Коричневый",
	[62] = "Темно-бордовый",
	[63] = "Светло-серый",
	[64] = "Светло-бежевый",
	[65] = "Оранжевый",
	[66] = "Темно-бордовый",
	[67] = "Серый",
	[68] = "Светло-фиолетовый",
	[69] = "Бежевый",
	[70] = "Темно-бордовый",
	[71] = "Серый",
	[72] = "Темно-серый",
	[73] = "Светло-коричневый",
	[74] = "Темно-бордовый",
	[75] = "Темно-серый",
	[76] = "Светло-бежевый",
	[77] = "Бежевый",
	[78] = "Темно-бордовый",
	[79] = "Темно-фиолетовый",
	[80] = "Серый",
	[81] = "Серый",
	[82] = "Темно-бордовый",
	[83] = "Темно-серый",
	[84] = "Темно-коричневый",
	[85] = "Темно-бордовый",
	[86] = "Темно-зеленый",
	[87] = "Темно-синий",
	[88] = "Серый",
	[89] = "Светло-бежевый",
	[90] = "Светло-серый",
	[91] = "Темно-синий",
	[92] = "Серый",
	[93] = "Темно-фиолетовый",
	[94] = "Темно-синий",
	[95] = "Темно-фиолетовый",
	[96] = "Светло-серый",
	[97] = "Серый",
	[98] = "Темно-синий",
	[99] = "Светло-коричневый",
	[100] = "Темно-синий",
	[101] = "Темно-фиолетовый",
	[102] = "Бежевый",
	[103] = "Темно-синий",
	[104] = "Коричневый",
	[105] = "Серый",
	[106] = "Темно-синий",
	[107] = "Светло-бежевый",
	[108] = "Темно-синий",
	[109] = "Серый",
	[110] = "Серый",
	[111] = "Светло-серый",
	[112] = "Серый",
	[113] = "Темно-коричневый",
	[114] = "Темно-серый",
	[115] = "Темно-бордовый",
	[116] = "Темно-фиолетовый",
	[117] = "Темно-бордовый",
	[118] = "Светло-синий",
	[119] = "Серый",
	[120] = "Светло-серый",
	[121] = "Темно-бордовый",
	[122] = "Серый",
	[123] = "Темно-коричневый",
	[124] = "Темно-бордовый",
	[125] = "Темно-фиолетовый",
	[126] = "Розовый",
	[127] = "Черный",
	[128] = "Темно-зеленый",
	[129] = "Темно-бордовый",
	[130] = "Темно-синий",
	[131] = "Темно-коричневый",
	[132] = "Темно-бордовый",
	[133] = "Темно-зеленый",
	[134] = "Темно-фиолетовый",
	[135] = "Синий",
	[136] = "Фиолетовый",
	[137] = "Темно-зеленый",
	[138] = "Светло-серый",
	[139] = "Темно-синий",
	[140] = "Серый",
	[141] = "Серый",
	[142] = "Коричневый",
	[143] = "Серый",
	[144] = "Темно-синий",
	[145] = "Светло-зеленый",
	[146] = "Розовый",
	[147] = "Темно-бордовый",
	[148] = "Темно-серый",
	[149] = "Темно-коричневый",
	[150] = "Темно-бордовый",
	[151] = "Темно-зеленый",
	[152] = "Темно-синий",
	[153] = "Темно-зеленый",
	[154] = "Темно-синий",
	[155] = "Светло-серый",
	[156] = "Бежевый",
	[157] = "Серый",
	[158] = "Темно-бордовый",
	[159] = "Темно-коричневый",
	[160] = "Темно-зеленый",
	[161] = "Темно-синий",
	[162] = "Темно-синий",
	[163] = "Светло-серый",
	[164] = "Темно-фиолетовый",
	[165] = "Серый",
	[166] = "Серый",
	[167] = "Темно-синий",
	[168] = "Темно-синий",
	[169] = "Серый",
	[170] = "Серый",
	[171] = "Темно-синий",
	[172] = "Темно-зеленый",
	[173] = "Темно-коричневый",
	[174] = "Темно-синий",
	[175] = "Темно-бордовый",
	[176] = "Синий",
	[177] = "Серый",
	[178] = "Темно-синий",
	[179] = "Темно-бордовый",
	[180] = "Темно-коричневый",
	[181] = "Темно-серый",
	[182] = "Темно-бордовый",
	[183] = "Темно-коричневый",
	[184] = "Серый",
	[185] = "Серый",
	[186] = "Темно-зеленый",
	[187] = "Темно-зеленый",
	[188] = "Темно-коричневый",
	[189] = "Темно-фиолетовый",
	[190] = "Темно-синий",
	[191] = "Темно-зеленый",
	[192] = "Светло-серый",
	[193] = "Серый",
	[194] = "Темно-бордовый",
	[195] = "Темно-зеленый",
	[196] = "Серый",
	[197] = "Коричневый",
	[198] = "Темно-синий",
	[199] = "Темно-серый",
	[200] = "Серый",
	[201] = "Темно-фиолетовый",
	[202] = "Темно-коричневый",
	[203] = "Темно-фиолетовый",
	[204] = "Серый",
	[205] = "Темно-синий",
	[206] = "Темно-фиолетовый",
	[207] = "Темно-синий",
	[208] = "Темно-фиолетовый",
	[209] = "Темно-синий",
	[210] = "Темно-фиолетовый",
	[211] = "Темно-синий",
	[212] = "Темно-коричневый",
	[213] = "Серый",
	[214] = "Темно-коричневый",
	[215] = "Темно-зеленый",
	[216] = "Темно-коричневый",
	[217] = "Синий",
	[218] = "Бежевый",
	[219] = "Темно-бордовый",
	[220] = "Розовый",
	[221] = "Желтый",
	[222] = "Оранжевый",
	[223] = "Темно-синий",
	[224] = "Темно-бордовый",
	[225] = "Темно-желтый",
	[226] = "Зеленый",
	[227] = "Темно-зеленый",
	[228] = "Светло-оранжевый",
	[229] = "Зеленый",
	[230] = "Коричневый",
	[231] = "Оранжевый",
	[232] = "Розовый",
	[233] = "Светло-розовый",
	[234] = "Темно-зеленый",
	[235] = "Темно-зеленый",
	[236] = "Темно-серый",
	[237] = "Розовый",
	[238] = "Оранжевый",
	[239] = "Оранжевый",
	[240] = "Светло-голубой",
	[241] = "Светло-зеленый",
	[242] = "Бордовый",
	[243] = "Зеленый",
	[244] = "Коричневый",
	[245] = "Темно-зеленый",
	[246] = "Голубой",
	[247] = "Серый",
	[248] = "Бордовый",
	[249] = "Бордовый",
	[250] = "Белый",
	[251] = "Серый",
	[252] = "Серый",
	[253] = "Белый",
	[254] = "Светло-коричневый",
	[255] = "Темно-синий",
}

function util.inflectColorName(color)
	local endings = {
		["ый"] = "ого",
		["ий"] = "его",
		["ой"] = "ого",
		["ый"] = "ого",
		["ая"] = "ой",
		["ое"] = "ого",
		["ие"] = "их",
	}

	local lastTwoLetters = string.sub(color, -2)

	local newEnding = endings[lastTwoLetters]

	if newEnding then
		return string.sub(color, 1, -3) .. newEnding
	else
		local lastLetter = string.sub(color, -1)
		local newEnding = endings[lastLetter]

		if newEnding then
			return string.sub(color, 1, -2) .. newEnding
		else
			return color
		end
	end
end

---@class Thread
---@field runner fun(...): any
---@field thread table
---@field run fun(self, ...)
---@field listen fun(self, res: fun(any), rej: fun(err: string, stacktrace: string?))

---@param func fun(...): boolean, any
---@return Thread
function util.newThread(func)
	local effil = require("effil")
	if type(func) ~= "function" then
		error("Expected function, got " .. type(func))
	end

	local h = {
		runner = effil.thread(func),
	}

	function h:run(...)
		self.thread = self.runner(...)
	end

	---@param res? fun(any)
	---@param rej? fun(err:string, stacktrace:string?)
	---@return table
	function h:listen(res, rej)
		res = res or function() end
		rej = rej or function(err)
			print(err)
		end

		if not self.thread then
			error("Run thread first.")
		end
		lua_thread.create(function()
			while self.thread:status() == "running" do
				wait(0)
			end
			local status, err, stack = self.thread:status()
			if status == "failed" then
				rej(err, stack)
				return
			end

			local success, result = self.thread:get()
			if success then
				res(result)
			else
				rej(result)
			end
		end)
	end

	return h
end

---Скачивает асинхронно файл из URL в указанный путь
---@param url string @URL
---@param path string @Путь к файлу, в который будет сохранен скачанный файл
---@param callback? fun(type: "downloading"|"finished"|"error", pos: number, total_size?: number) @Функция, которая будет вызвана при изменении прогресса скачивания или завершении
---@param progressInterval? number @Интервал в секундах между вызовами callback, по умолчанию 0.1
function util.downloadToFile(url, path, callback, progressInterval)
	callback = callback or function() end
	progressInterval = progressInterval or 0.1

	if not MONET_VERSION then
		local dlstatus = require('moonloader').download_status
		return downloadUrlToFile(url, path, function(id, status, p1, p2)
			if status == dlstatus.STATUS_DOWNLOADINGDATA then
				callback("downloading", p1, p2)
			elseif status == dlstatus.STATUS_ENDDOWNLOADDATA then
				callback("finished", p1)
			end
		end)
	end

	local effil = require("effil")
	local progressChannel = effil.channel(0)

	local runner = effil.thread(function(url, path)
		local http = require("socket.http")
		local ltn = require("ltn12")

		local r, c, h = http.request({
			method = "HEAD",
			url = url,
		})

		if c ~= 200 then
			return false, c
		end
		local total_size = h["content-length"]

		local f = io.open(path, "wb")
		if not f then
			return false, "failed to open file"
		end
		local success, res, status_code = pcall(http.request, {
			method = "GET",
			url = url,
			sink = function(chunk, err)
				local clock = os.clock()
				if chunk and not lastProgress or (clock - lastProgress) >= progressInterval then
					progressChannel:push("downloading", f:seek("end"), total_size)
					lastProgress = os.clock()
				elseif err then
					progressChannel:push("error", err)
				end

				return ltn.sink.file(f)(chunk, err)
			end,
		})

		if not success then
			return false, res
		end

		if not res then
			return false, status_code
		end

		return true, total_size
	end)
	local thread = runner(url, path)

	local function checkStatus()
		local tstatus = thread:status()
		if tstatus == "failed" or tstatus == "completed" then
			local result, value = thread:get()

			if result then
				callback("finished", value)
			else
				callback("error", value)
			end

			return true
		end
	end

	lua_thread.create(function()
		if checkStatus() then
			return
		end

		while thread:status() == "running" do
			if progressChannel:size() > 0 then
				local type, pos, total_size = progressChannel:pop()
				callback(type, pos, total_size)
			end
			wait(0)
		end

		checkStatus()
	end)
end

return util
 end)
package.preload['src.imgui_util'] = (function (...)
local imutil = {}

function imutil.shortifyText(text, parentWidth)
	local width = parentWidth or imgui.GetWindowContentRegionWidth()
	local calc = imgui.CalcTextSize(text)
	if calc.x > width then
		local len = math.floor(text:len() * (width / calc.x))
		return text:sub(1, len - 3) .. "..."
	end
	return text
end

function imutil.GetMiddleColumnX(count)
	local window_width = imgui.GetWindowWidth()
	local total_spacing = imgui.GetStyle().ItemSpacing.x * (count - 1)
	local total_columns_width = window_width - (total_spacing + imgui.GetStyle().FramePadding.x * 2 * count)
	return total_columns_width / (3 * count)
end

function imutil.GetMiddleButtonX(count)
	local width = imgui.GetWindowContentRegionWidth()
	local space = imgui.GetStyle().ItemSpacing.x
	return count == 1 and width or width / count - ((space * (count - 1)) / count)
end

function imutil.ToggleButtonIcon(icon_on, icon_off, state, size)
	size = size or imgui.ImVec2(30 * MDS, 30 * MDS)
	if state then
		return imgui.Button(icon_on, size)
	else
		return imgui.Button(icon_off, size)
	end
end

function imutil.GetEndPosButtonX(size, count)
	local width = imgui.GetWindowWidth()
	local space = imgui.GetStyle().FramePadding.x
	return width - (size.x * count) - (space * count)
end

function imutil.Setting(name, setting, callback, close_button)
	close_button = close_button == nil and true or close_button
	imgui.BeginChild(name, imgui.ImVec2(0, 40 * MDS), true)
	imgui.Text(setting)
	imgui.SameLine()

	local size = imgui.ImVec2(30 * MDS, 30 * MDS)
	imgui.SetCursorPosX(imutil.GetEndPosButtonX(size, 1))
	if imgui.Button(fa.PEN, size) then
		imgui.OpenPopup(name)
	end

	if
		imgui.BeginPopupModal(
			name,
			_,
			imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove
		)
	then
		imgui.SetWindowSizeVec2(imgui.ImVec2(400 * MDS, 200 * MDS))
		callback()
		if close_button then
			imgui.Dummy(imgui.ImVec2(0, 30 * MDS))
			imgui.SetCursorPosY(
				imgui.GetWindowHeight() - imgui.GetStyle().FramePadding.y - 30 * MDS + imgui.GetScrollY()
			)
			if
				imutil.CenterButton(
					fa.XMARK .. u8(" Закрыть"),
					imgui.ImVec2(imgui.GetWindowWidth() * 0.85, 30 * MDS)
				)
			then
				imgui.CloseCurrentPopup()
			end
		end
		imgui.EndPopup()
	end

	imgui.EndChild()
end

function imutil.CenterButton(label, bsize, alignment)
	bsize = bsize or imgui.ImVec2(0, 0)
	alignment = alignment or 0.5
	local style = imgui.GetStyle()

	local size = bsize.x + style.FramePadding.x * 2.0
	local avail = imgui.GetContentRegionAvail().x

	local off = (avail - size) * alignment
	if off > 0.0 then
		imgui.SetCursorPosX(imgui.GetCursorPosX() + off)
	end

	return imgui.Button(label, bsize)
end

function imutil.CenterError(text)
	local width = imgui.GetWindowWidth()
	local calc = imgui.CalcTextSize(text)
	imgui.Text(fa.BUG .. u8(" "))
	imgui.SameLine()
	imgui.SetCursorPosX(width / 2 - calc.x / 2)
	imgui.TextColored(imgui.ImVec4(1, 0, 0, 1), text)
end

function imutil.CenterText(text)
	local width = imgui.GetWindowWidth()
	local calc = imgui.CalcTextSize(text)
	imgui.SetCursorPosX(width / 2 - calc.x / 2)
	imgui.Text(text)
end

function imutil.ButtonWrappedTextCenter(text, size)
    local is_pressed = imgui.Button("##"..text, size)
    local button_min, button_max = imgui.GetItemRectMin(), imgui.GetItemRectMax()
    
    local lines = {}
    for line in text:gmatch("[^\n]+") do
        table.insert(lines, line)
    end
    
    -- Get draw list and add text for each line
    local draw_list = imgui.GetWindowDrawList()
    local text_size = imgui.CalcTextSize(text)
    local line_height = text_size.y / #lines
    local text_y = button_min.y + (button_max.y - button_min.y - text_size.y) / 2
    
    for i, line in ipairs(lines) do
        local text_size_line = imgui.CalcTextSize(line)
        local text_x = button_min.x + (button_max.x - button_min.x - text_size_line.x) / 2
        local text_pos = imgui.ImVec2(text_x, text_y + (i - 1) * line_height)
        draw_list:AddText(text_pos, imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.Text]), line)
    end
    
    return is_pressed
end
function imutil.BackgroundButton(label, open, pos, size, color, movable)
	if not pos then
		error("pos is nil")
	end
	size = size or imgui.ImVec2(0, 0)
	color = color or imgui.ImVec4(0.0, 0.0, 1.0, 0.5) -- deepskyblue

	local cond = movable and imgui.Cond.Once or imgui.Cond.Always
	imgui.SetNextWindowPos(pos, cond)
	imgui.SetNextWindowSize(size, cond)
	if movable then
		imgui.Begin("##bg", open)
	else
		imgui.Begin(
			"##bg",
			open,
			imgui.WindowFlags.NoTitleBar
				+ imgui.WindowFlags.NoResize
				+ imgui.WindowFlags.NoMove
				+ imgui.WindowFlags.NoBackground
		)
	end
	imgui.PushStyleColor(imgui.Col.Button, color)
	local button = imgui.Button(label, imgui.GetContentRegionAvail())

	local pos, size = imgui.GetWindowPos(), imgui.GetWindowSize()
	imgui.PopStyleColor()
	imgui.End()

	return button, pos, size
end

return imutil
 end)
package.preload['src.doubleclickped'] = (function (...)
local WIDGET_PED_MOVE = 0xA7
local touch_events = {
    POP = 1,
    PUSH = 2,
    MOVE = 3
  }

local mod = {}

local lastClick = nil
local lastClickTime = nil
mod.doubleClickThreshold = 0.5
mod.clickRadius = 8

function findPedByRaycasts(screenX, screenY, maxDistance)
    local worldX, worldY, worldZ = convertScreenCoordsToWorld3D(screenX, screenY, maxDistance)

    local camX, camY, camZ = getActiveCameraCoordinates()
    local res, col = processLineOfSight(camX, camY, camZ, worldX, worldY, worldZ, true, false, true)
    
    if res and col.entityType == 3 then
        return col.entity
    end

    return nil
end

local function onTouch(type, id, x, y)
    local currentTime = os.clock()

    if isWidgetPressed(WIDGET_PED_MOVE, 0) then
        return
    end

    if type == touch_events.PUSH and lastClick ~= nil and distance(lastClick, {x, y}) <= mod.clickRadius and currentTime - lastClickTime <= mod.doubleClickThreshold then
        local handle = findPedByRaycasts(x, y, 50)

        if handle then
            local ped = getCharPointerHandle(handle)
            mod.onDoubleClickedPed(ped, x, y)
        end
        
        lastClick = nil
        lastClickTime = nil
    elseif type == touch_events.PUSH then
        lastClick = {x, y}
        lastClickTime = currentTime
    end
end
if MONET_VERSION then addEventHandler('onTouch', onTouch) end

function mod.onDoubleClickedPed(ped, x,y) end

function distance(point1, point2)
    local dx = point1[1] - point2[1]
    local dy = point1[2] - point2[2]
    return math.sqrt(dx * dx + dy * dy)
end

return mod end)
package.preload['src.commandloader'] = (function (...)
---@class Param
---@field name string
---@field type? string
---@field default? string
---@field required boolean

---@class Command
---@field name string
---@field text string
---@field description? string
---@field enabled? boolean
---@field params? Param[]
---@field errors? string[]
---@field hasErrors boolean

---@class CommandSource
---@field name string
---@field description? string
---@field enabled? boolean
---@field commands Command[]
---@field filepath string

---@class ValidatorError
---@field error_code number
---@field details ValidatorErrorDetails | string

---@class ValidatorErrorDetails
---@field param_id? number
---@field command_id? string

local weapons = require "game.weapons"
local sandbox = require("lib.sandbox")

local util = require("src.util")
local isEmpty = util.isEmpty

local CommandLoader = {
	---@type CommandSource[]
	sources = {},
	dir = "commands",
}

local path = getWorkingDirectory() .. PATH_SEPARATOR .. CommandLoader.dir
if not lfs.attributes(path) then
	lfs.mkdir(path)
end

CommandLoader.typeProcessor = {
	["player"] = function(param)
		local playerid = tonumber(param)

		local myid = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))
		
		if not playerid then
			return false, "Неверный формат ID игрока"
		end

		if playerid == myid then
			return myid
		end

		if not sampIsPlayerConnected(playerid) then
			return false, "Игрок не найден"
		end

		return playerid
	end,
	["number"] = function(param)
		local num = tonumber(param)
		if not num then
			return false, "Неверный формат числа"
		end
		return num
	end,
	["bool"] = function(param)
		local bools = {
			["true"] = true,
			["false"] = false,
			["1"] = true,
			["0"] = false,
		}
		return bools[param] or false, "Неверный формат логического значения, используйте true/false или 1/0"
	end,
	["string"] = function(param)
		return param
	end,
}

CommandLoader.env = {
	["wait"] = function(ms)
		state.waitm = tonumber(ms)
	end,
	["time"] = function()
		return os.date("%H:%M:%S")
	end,
	["date"] = function()
		return os.date("%d.%m.%Y")
	end,
	["my_gun"] = function()
		return getCurrentCharWeapon(PLAYER_PED)
	end,
	["my_gun_weapon"] = function()
		return weapons.names[getCurrentCharWeapon(PLAYER_PED)]
	end,
	["my_lvl"] = function()
		local _, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
		return sampGetPlayerScore(id)
	end,
	["my_armor"] = function()
		local _, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
		return sampGetPlayerArmor(id)
	end,
	["my_hp"] = function()
		local _, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
		return sampGetPlayerHealth(id)
	end,
	["my_id"] = function()
		local _, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
		return id
	end,
	["my_nick"] = function()
		local _, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
		return sampGetPlayerNickname(id)
	end,
	["my_name"] = function()
		local _, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
		local nick = sampGetPlayerNickname(id)

		return nick:sub(1, nick:find("_") - 1)
	end,
	["my_surname"] = function()
		local _, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
		local nick = sampGetPlayerNickname(id)

		return nick:sub(nick:find("_") + 1)
	end,
	["my_rpnick"] = function()
		return cfg.general.nickname
	end,
	["my_rpname"] = function()
		local nick = cfg.general.nickname

		return nick:sub(1, (nick:find(" ") or nick:find("_")) - 1)
	end,
	["my_rpsurname"] = function()
		local nick = cfg.general.nickname

		return nick:sub((nick:find(" ") or nick:find("_")) + 1)
	end,
	["my_car"] = function()
		if isCharInAnyCar(PLAYER_PED) then 
			local veh = storeCarCharIsInNoSave(PLAYER_PED)
			local idcar = getCarModel(veh)

			return util.arzcars[idcar] or "Неизвестно"
		end
		
		return nil
	end,
	
	["my_carcolor"] = function()
		if isCharInAnyCar(PLAYER_PED) then 
			local veh = storeCarCharIsInNoSave((PLAYER_PED))
			local color1, color2 = getCarColours(veh)
			
			return util.VehicleColoursRussianTable[color1]
		end
		
		return nil
	end,
	["my_fps"] = function()
		return imgui.GetIO().Framerate
	end,
	["random"] = function(n, n2)
		return math.random(n, n2)
	end,
	["city"] = function()
		local city = {
			[0] = "пригород",
			[1] = "Los Santos",
			[2] = "San Fierro",
			[3] = "Las Venturas"
		}

		return city[getCityPlayerIsIn(PLAYER_HANDLE)]
	end,

	["nickid"] = function(id)
		return sampGetPlayerNickname(id)
	end,
	["rpnickid"] = function(id)
		return util.TranslateNick(sampGetPlayerNickname(id))
	end,
	["carid"] = function(id)
		local res, char = sampGetCharHandleBySampPlayerId(id)
		if res and isCharInAnyCar(char) then 
			local veh = storeCarCharIsInNoSave(char)
			local idcar = getCarModel(veh)

			return res and util.arzcars[idcar] or "Неизвестно"
		end
		
		return nil
	end,
	["carcolorid"] = function(id)
		local res, char = sampGetCharHandleBySampPlayerId(id)
		if res and isCharInAnyCar(char) then 
			local veh = storeCarCharIsInNoSave(char)
			local color1, color2 = getCarColours(veh)
			
			return util.VehicleColoursRussianTable[color1]
		end
		
		return nil
	end,
	["inflectcolor"] = function(color)
		if not color then
			return
		end
		return util.inflectColorName(color)
	end,
	["car_id_nearest"] = function(maxDist, maxPlayers)
		maxDist = maxDist or 50
		maxPlayers = maxPlayers or false

		local res, HandleVeh, Distance, posX, posY, posZ, countPlayers = util.GetNearestCarByPed(PLAYER_PED, maxDist, maxPlayers)

		return res and select(2, sampGetVehicleIdByCarHandle(HandleVeh))
	end,
	["car_driver_id"] = function(car_id)
		local res, car = sampGetCarHandleBySampVehicleId(car_id)
		
		if not res then
			return
		end
		local driver = getDriverOfCar(car)

		return driver and select(2, sampGetPlayerIdByCharHandle(driver))
	end,
	["player_id_nearest"] = function(maxDist)
		maxDist = maxDist or 50
		
		local nearest = util.getNearestPedByPed(PLAYER_PED, maxDist)

		return nearest and select(2, sampGetPlayerIdByCharHandle(nearest)) or nil
	end,
	["chooseMenu"] = function(title, items)
		table.insert(state.menus, {
			name = title,
			render = imgui.new.bool(true),
			choices = items
		})
	end,
	["choice"] = function(name, text)
		return {
			name = name,
			text = text
		}
	end,
}
CommandLoader.env_docs = {
	{
		name="wait",
		description="Ждать N миллисекунд",
		params={"мс"}
	},
	{
		name="time",
		description="Возвращает текущее время",
		params={}
	},
	{
		name="date",
		description="Возвращает текущую дату",
		params={}
	},
	{
		name="my_gun",
		description="Возвращает ID оружия игрока",
		params={}
	},
	{
		name="my_gun_weapon",
		description="Возвращает название оружия игрока",
		params={}
	},
	{
		name="my_lvl",
		description="Возвращает уровень игрока",
		params={}
	},
	{
		name="my_armor",
		description="Возвращает броню игрока",
		params={}
	},
	{
		name="my_hp",
		description="Возвращает здоровье игрока",
		params={}
	},
	{
		name="my_id",
		description="Возвращает ID игрока",
		params={}
	},
	{
		name="my_nick",
		description="Возвращает ник игрока",
		params={}
	},
	{
		name="my_name",
		description="Возвращает имя игрока",
		params={}
	},
	{
		name="my_surname",
		description="Возвращает фамилию игрока",
		params={}
	},
	{
		name="my_rpnick",
		description="Возвращает RP-ник игрока",
		params={}
	},
	{
		name="my_rpname",
		description="Возвращает имя RP-ника игрока",
		params={}
	},
	{
		name="my_rpsurname",
		description="Возвращает фамилию RP-ника игрока",
		params={}
	},
	{
		name="my_car",
		description="Возвращает название машины игрока",
		params={}
	},
	{
		name="my_carcolor",
		description="Возвращает цвет машины игрока",
		params={}
	},
	{
		name="my_fps",
		description="Возвращает FPS",
		params={}
	},
	{
		name="random",
		description="Возвращает случайное число в диапазоне от N до N2",
		params={"N", "N2"}
	},
	{
		name="city",
		description="Возвращает название города, в котором находится игрок",
		params={},
	},
	{
		name="nickid",
		description="Возвращает ник игрока по ID",
		params={"ID"}
	},
	{
		name="rpnickid",
		description="Возвращает RP-ник игрока по ID",
		params={"ID"}
	},
	{
		name="carid",
		description="Возвращает название машины игрока по ID",
		params={"ID"}
	},
	{
		name="carcolorid",
		description="Возвращает цвет машины игрока по ID",
		params={"ID"}
	},
	{
		name="inflectcolor",
		description="Склоняет название цвета",
		params={"цвет"}
	},
	{
		name="car_id_nearest",
		description="Возвращает ID ближайшей машины",
		params={"радиус?", "максимальное количество игроков вокруг машины?"}
	},
	{
		name="car_driver_id",
		description="Возвращает ID водителя машины",
		params={"ID машины"}
	},
	{
		name="player_id_nearest",
		description="Возвращает ID ближайшего игрока",
		params={"радиус"}
	},
	{
		name="chooseMenu",
		description="Открыть меню выбора",
		params={"заголовок", "варианты"}
	},
	{
		name="choice",
		description="Создать вариант для меню",
		params={"название", "текст"}
	},
}

function scanDirectory(directory, scanSubdirs)
	local files = {}
	local dirs = {}
	for file in lfs.dir(directory) do
		if file ~= "." and file ~= ".." then
			local filePath = directory .. PATH_SEPARATOR .. file
			local mode = lfs.attributes(filePath, "mode")
			if mode == "file" and file:find(".json$") then
				table.insert(files, file)
			elseif scanSubdirs and mode == "directory" then
				local subdirFiles = scanDirectory(filePath, false)
				if next(subdirFiles) then
					dirs[file] = subdirFiles.files
				end
			end
		end
	end

	return files, dirs
end

function CommandLoader.toMimguiTable(source)
	local tbl = {}

	tbl.name = imgui.new.char[128](u8(source.name))
	tbl.description = imgui.new.char[512](u8(source.description))
	tbl.enabled = imgui.new.bool(source.enabled)
	tbl.filepath = imgui.new.char[128](source.filepath)

	tbl.commands = {}
	for _, cmd in ipairs(source.commands) do
		local ctbl = {}
		ctbl.name = imgui.new.char[128](cmd.name)
		ctbl.text = imgui.new.char[1024](u8(cmd.text))
		ctbl.description = imgui.new.char[256](u8(cmd.description))
		ctbl.enabled = imgui.new.bool(cmd.enabled)

		ctbl.params = {}
		for _, param in ipairs(cmd.params) do
			local ptbl = {}
			ptbl.name = imgui.new.char[128](u8(param.name))
			ptbl.type = imgui.new.char[128](param.type)
			ptbl.default = imgui.new.char[128](u8(param.default))
			ptbl.required = imgui.new.bool(param.required)

			table.insert(ctbl.params, ptbl)
		end

		table.insert(tbl.commands, ctbl)
	end

	return tbl
end

function CommandLoader.fromMimguiTable(tbl)
	local source = {}
	source.name = u8:decode(ffi.string(tbl.name))
	source.description = u8:decode(ffi.string(tbl.description))
	source.enabled = tbl.enabled[0]
	source.filepath = ffi.string(tbl.filepath or "")

	source.commands = {}
	for _, cmd in ipairs(tbl.commands) do
		local ctbl = {}
		ctbl.name = ffi.string(cmd.name)
		ctbl.text = u8:decode(ffi.string(cmd.text))
		ctbl.description = u8:decode(ffi.string(cmd.description))
		ctbl.enabled = cmd.enabled[0]

		ctbl.params = {}
		for _, param in ipairs(cmd.params) do
			local ptbl = {}
			ptbl.name = u8:decode(ffi.string(param.name))
			ptbl.type = ffi.string(param.type)
			ptbl.default = u8:decode(ffi.string(param.default))
			ptbl.required = param.required[0]

			table.insert(ctbl.params, ptbl)
		end

		table.insert(source.commands, ctbl)
	end

	return source
end

CommandLoader.errorDescriptions = {
	[1] = "Имя источника не может быть пустым",
	[2] = "Имя команды не может быть пустым",
	[3] = "Текст команды не может быть пустым",
	[4] = "Имя параметра не может быть пустым",
	[5] = "Тип параметра не может быть пустым",
	[6] = "Неизвестный тип параметра",
}

---@param source CommandSource
---@param filename string
---@return ValidatorError[], CommandSource @Ошибки, источник
function CommandLoader.validateSource(source, filename)
	local errors = {}

	if isEmpty(source.name) then
		table.insert(errors, { error_code = 1, details = "source" })
	end

	if source.enabled == nil then
		source.enabled = true
	end

	if not source.commands then
		source.commands = {}
	end

	for i, cmd in ipairs(source.commands) do
		local command, cmd_errors = CommandLoader.validateCommand(cmd)
		for _, error_msg in ipairs(cmd_errors) do
			table.insert(errors, error_msg)
		end

		source.commands[i] = command
	end

	return errors, source
end

---@param command table
---@return Command, ValidatorError[] @Команда, ошибки
function CommandLoader.validateCommand(command)
	---@type ValidatorError[]
	local errors = {}

	if isEmpty(command.name) then
		table.insert(errors, { error_code = 2, details = command.id })
	end

	if isEmpty(command.text) then
		table.insert(errors, { error_code = 3, details = command.id })
	end

	if command.enabled == nil then
		command.enabled = true
	end

	if command.params then
		for i, param in ipairs(command.params) do
			local param_errors = {}
			if isEmpty(param.name) then
				table.insert(param_errors, { error_code = 4, details = command.id })
			end

			if not param.type then
				param.type = "string"
			end

			if not param.required then
				param.required = true
			end

			if not isEmpty(param.default) and param.required then
				param.required = false
			end

			if not CommandLoader.typeProcessor[param.type] then
				table.insert(param_errors, { error_code = 6, details = { param_id = i, command_id = command.id } })
			end

			for _, error_msg in ipairs(param_errors) do
				table.insert(errors, error_msg)
			end
		end
	else
		command.params = {}
	end

	command.errors = errors
	command.hasErrors = #errors > 0

	if command.hasErrors then
		command.enabled = false
	end

	return command, errors
end

function CommandLoader.processFile(filePath)
	local file = io.open(filePath, "r")
	if not file then
		error("Failed to open file: " .. filePath)
		return
	end

	local content = file:read("*a")
	file:close()
	local success, data = pcall(decodeJson, content)

	if not success then
		print("Failed to parse file " .. filePath)
		return
	end
	if data then
		local gerrors, source = CommandLoader.validateSource(data, filePath)

		if #gerrors > 0 then
			print("Errors in file " .. filePath)
			for _, error in ipairs(gerrors) do
				print(CommandLoader.errorDescriptions[error.error_code], error.details)
			end
		end

		source.filepath = filePath
		table.insert(CommandLoader.sources, source)
	end
end

function CommandLoader.load()
	local files, dirs = scanDirectory(getWorkingDirectory() .. PATH_SEPARATOR ..CommandLoader.dir, true)
	CommandLoader.processFiles(files, CommandLoader.dir)

	for dir, files in pairs(dirs) do
		local directory = CommandLoader.dir .. PATH_SEPARATOR .. dir
		CommandLoader.processFiles(files, directory)
	end
end

function CommandLoader.reload()
	CommandLoader.unregisterCommands()
	CommandLoader.sources = {}
	CommandLoader.load()
	CommandLoader.registerCommands()
end

function CommandLoader.processFiles(files, directory)
	for _, file in ipairs(files) do
		local filePath = getWorkingDirectory() .. PATH_SEPARATOR .. directory .. PATH_SEPARATOR .. file
		CommandLoader.processFile(filePath)
	end
end

function CommandLoader.saveSource(source)
	local file = io.open(source.filepath, "w")
	if not file then
		print("Failed to open file " .. source.filepath)
		return
	end

	local data = encodeJson(source)
	file:write(data)
	file:close()
end

function CommandLoader.removeSource(source)
	os.remove(source.filepath)
end

function CommandLoader.findSourceByName(name)
	for _, source in ipairs(CommandLoader.sources) do
		if source.name == name then
			return source
		end
	end
end

function CommandLoader.iterateCommands()
	return coroutine.wrap(function()
		for _, source in ipairs(CommandLoader.sources) do
			for _, cmd in ipairs(source.commands) do
				coroutine.yield(cmd)
			end
		end
	end)
end

function CommandLoader.unregisterCommands()
	for cmd in CommandLoader.iterateCommands() do
		sampUnregisterChatCommand(cmd.name)
	end
end

function CommandLoader.registerCommands()
	for _, source in ipairs(CommandLoader.sources) do
		for _, cmd in ipairs(source.commands) do
			if source.enabled and not cmd.hasErrors and cmd.enabled then
				local reg = sampRegisterChatCommand(cmd.name, function(params)
					local args = {}
					local aparam = string.gmatch(params, "[^%s]+")
					for _, pdata in pairs(cmd.params) do
						local ap = aparam()

						if not ap and pdata.required then
							sampAddChatMessage(
								cmd.name..": Использование: " .. generateUsage(cmd.name, cmd.params),
								-1
							)
							return
						elseif not ap then
							args[pdata.name] = pdata.default or ""
							break
						end

						local proc = CommandLoader.typeProcessor[pdata.type]

						local arg, err = proc(ap)
						if not arg then
							sampAddChatMessage(cmd.name..": "..err, -1)
							return
						end

						args[pdata.name] = arg
					end

					local text = cmd.text
					lua_thread.create(function()
						local i = 1
						for line in text:gmatch("[^\r\n]+") do
							line = line:gsub("~{(.-)}~", function(expr)
								local ok, result = pcall(sandbox.run, expr:find("^return") and expr or "return "..expr, {
									env = util.merge(args, cfg.general, CommandLoader.env),
								})

								if not ok then
									print(result)
									sampAddChatMessage(result, -1)
									return ""
								end

								return tostring(result or "")
							end)

							if state.waitm then
								wait(state.waitm)
								state.waitm = nil
							elseif i > 1 then
								wait(cfg.general.default_delay)
							end

							if not isEmpty(line) then
								sampProcessChatInput(line)
							end

							i = i + 1
						end
					end)
				end)
			end
		end
	end

	sampRegisterChatCommand("eval", function(params)
		local ok, result = xpcall(sandbox.run, debug.traceback, "return "..params, {
			env = util.merge(cfg.general, CommandLoader.env),
		})

		if not ok then
			print(result)
		end

		sampAddChatMessage(tostring(result), -1)
	end)
end

function CommandLoader.sourceCount()
	return #CommandLoader.sources
end

function CommandLoader.commandCount()
	local count = 0
	for _ in CommandLoader.iterateCommands() do
		count = count + 1
	end
	return count
end

return CommandLoader
 end)
script_name("MonetBinder")
script_author("OSPx")
script_description([[
	A functional binder in Lua for Arizona RP Mobile utilizing the MonetLoader Runtime
	Функциональный биндер на Lua для Arizona RP Mobile
]])
script_url("https://github.com/osp54/MonetBinder")
script_version("1.0.1")

PATH_SEPARATOR = "/"
if MONET_VERSION == nil then
	PATH_SEPARATOR = "\\"
end

ffi = require("ffi")
lfs = require("lfs")
imgui = require("mimgui")

jsoncfg = require("lib.jsoncfg")
android = require("lib.android")

util = require("src.util")
imutil = require("src.imgui_util")
doubleclickped = require("src.doubleclickped")
commandloader = require("src.commandloader")

fa = require("fAwesome6_solid")
encoding = require("encoding")
encoding.default = "CP1251"
u8 = encoding.UTF8

cfg = {
	general = {
		default_delay = 1000,
		nickname = "",
		fraction = "",
		rank = "",
		rank_number = 0,
	},
	ui = {
		monet_binder_button = true,
		monet_binder_button_pos = {
			x = 340,
			y = 225,
		},
		monet_binder_button_size = {
			x = 60,
			y = 60,
		},
	},
}

local function mimguiState()
	local state = {}
	state.renderMainMenu = imgui.new.bool(false)
	state.mainMenuMenuPos = imgui.ImVec2(0, 0)
	state.renderFastMenu = imgui.new.bool(false)

	state.fastMenuPlayerId = nil
	state.fastMenuPos = imgui.ImVec2(0, 0)

	state.defaultDelayInput = imgui.new.int(cfg.general.default_delay)
	state.nicknameInput = imgui.new.char[256](u8(cfg.general.nickname))
	state.fractionInput = imgui.new.char[256](u8(cfg.general.fraction))
	state.rankInput = imgui.new.char[256](u8(cfg.general.rank))
	state.ranks = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" }
	state.ImRanks = imgui.new["const char*"][#state.ranks](state.ranks)
	state.rankNumberInput = imgui.new.int(cfg.general.rank_number - 1)

	state.monetBinderButton = imgui.new.bool(cfg.ui.monet_binder_button)
	state.monetBinderButtonMove = false

	state.selectedProfile = 0
	state.currentMsource = nil
	state.currentCommand = nil

	state.menus = {}
	return state
end

local allowedLuaDoc = {
	{
		is_function = true,
		name = "assert",
		description = "Вызывает ошибку, если условие ложно",
		params = { "condition", "message" },
	},
	{
		is_function = true,
		name = "error",
		description = "Вызывает ошибку",
		params = { "message" },
	},
	{
		is_function = true,
		name = "ipairs",
		description = "Возвращает итератор для перебора массива в порядке возрастания индекса",
		params = { "t" },
	},
	{
		is_function = true,
		name = "next",
		description = "Возвращает следующий элемент таблицы",
		params = { "table", "index" },
	},
	{
		is_function = true,
		name = "pairs",
		description = "Возвращает итератор для перебора таблицы в случайном порядке",
		params = { "t" },
	},
	{
		is_function = true,
		name = "pcall",
		description = "Вызывает функцию в защищенном режиме",
		params = { "function", "..." },
	},
	{
		is_function = true,
		name = "select",
		description = "Возвращает все параметры функции, начиная с индекса",
		params = { "index", "..." },
	},
	{
		is_function = true,
		name = "tonumber",
		description = "Преобразует строку в число",
		params = { "e", "base" },
	},
	{
		is_function = true,
		name = "tostring",
		description = "Преобразует значение в строку",
		params = { "e" },
	},
	{
		is_function = true,
		name = "type",
		description = "Возвращает тип значения",
		params = { "v" },
	},
	{
		is_function = true,
		name = "unpack",
		description = "Разпаковывает массив в список значений",
		params = { "list", "i", "j" },
	},
	{
		is_function = true,
		name = "xpcall",
		description = "Вызывает функцию в защищенном режиме",
		params = { "function", "msgh", "..." },
	},
	{
		is_module = true,
		name = "coroutine",
		description = "Модуль для работы с корутинами",
		doc = {
			{
				is_function = true,
				name = "create",
				description = "Создает новую корутину",
				params = { "f" },
			},
			{
				is_function = true,
				name = "resume",
				description = "Запускает корутину",
				params = { "co", "..." },
			},
			{
				is_function = true,
				name = "running",
				description = "Возвращает текущую корутину",
			},
			{
				is_function = true,
				name = "status",
				description = "Возвращает статус корутины",
				params = { "co" },
			},
			{
				is_function = true,
				name = "wrap",
				description = "Создает защищенную функцию",
				params = { "f" },
			},
			{
				is_function = true,
				name = "yield",
				description = "Приостанавливает корутину",
				params = { "..." },
			},
		},
	},
	{
		is_module = true,
		name = "math",
		description = "Модуль для математических операций",
		doc = {
			{
				is_function = true,
				name = "abs",
				description = "Модуль числа",
				params = { "x" },
			},
			{
				is_function = true,
				name = "acos",
				description = "Арккосинус",
				params = { "x" },
			},
			{
				is_function = true,
				name = "asin",
				description = "Арксинус",
				params = { "x" },
			},
			{
				is_function = true,
				name = "atan",
				description = "Арктангенс",
				params = { "x" },
			},
			{
				is_function = true,
				name = "atan2",
				description = "Арктангенс двух аргументов",
				params = { "y", "x" },
			},
			{
				is_function = true,
				name = "ceil",
				description = "Округление вверх",
				params = { "x" },
			},
			{
				is_function = true,
				name = "cos",
				description = "Косинус",
				params = { "x" },
			},
			{
				is_function = true,
				name = "cosh",
				description = "Гиперболический косинус",
				params = { "x" },
			},
			{
				is_function = true,
				name = "deg",
				description = "Преобразует радианы в градусы",
				params = { "x" },
			},
			{
				is_function = true,
				name = "exp",
				description = "Экспонента",
				params = { "x" },
			},
			{
				is_function = true,
				name = "fmod",
				description = "Остаток от деления",
				params = { "x", "y" },
			},
			{
				is_function = true,
				name = "floor",
				description = "Округление вниз",
				params = { "x" },
			},
			{
				is_function = true,
				name = "frexp",
				description = "Разбиение числа на мантиссу и экспоненту",
				params = { "x" },
			},
			{
				is_const = true,
				name = "huge",
				description = "Бесконечность",
			},
			{
				is_function = true,
				name = "ldexp",
				description = "Умножение числа на 2 в степени",
				params = { "m", "e" },
			},
			{
				is_function = true,
				name = "log",
				description = "Натуральный логарифм",
				params = { "x", "base" },
			},
			{
				is_function = true,
				name = "log10",
				description = "Десятичный логарифм",
				params = { "x" },
			},
			{
				is_function = true,
				name = "max",
				description = "Максимальное число",
				params = { "x", "..." },
			},
			{
				is_function = true,
				name = "min",
				description = "Минимальное число",
				params = { "x", "..." },
			},
			{
				is_function = true,
				name = "modf",
				description = "Целая и дробная часть числа",
				params = { "x" },
			},
			{
				is_const = true,
				name = "pi",
				description = "Число пи",
			},
			{
				is_function = true,
				name = "pow",
				description = "Возведение в степень",
				params = { "x", "y" },
			},
			{
				is_function = true,
				name = "rad",
				description = "Преобразует градусы в радианы",
				params = { "x" },
			},
			{
				is_function = true,
				name = "random",
				description = "Случайное число",
				params = { "m", "n" },
			},
			{
				is_function = true,
				name = "sin",
				description = "Синус",
				params = { "x" },
			},
			{
				is_function = true,
				name = "sinh",
				description = "Гиперболический синус",
				params = { "x" },
			},
			{
				is_function = true,
				name = "sqrt",
				description = "Квадратный корень",
				params = { "x" },
			},
			{
				is_function = true,
				name = "tan",
				description = "Тангенс",
				params = { "x" },
			},
			{
				is_function = true,
				name = "tanh",
				description = "Гиперболический тангенс",
				params = { "x" },
			},
		},
	},
	{
		is_module = true,
		name = "os",
		description = "Модуль для работы с операционной системой",
		doc = {
			{
				is_function = true,
				name = "clock",
				description = "Время работы программы",
			},
			{
				is_function = true,
				name = "difftime",
				description = "Разница между временем",
				params = { "t2", "t1" },
			},
			{
				is_function = true,
				name = "time",
				description = "Текущее время",
			},
		},
	},
	{
		is_module = true,
		name = "string",
		description = "Модуль для работы со строками",
		doc = {
			{
				is_function = true,
				name = "byte",
				description = "Возвращает числовое значение символа",
				params = { "s", "i", "j" },
			},
			{
				is_function = true,
				name = "char",
				description = "Возвращает символ по коду",
				params = { "..." },
			},
			{
				is_function = true,
				name = "find",
				description = "Поиск подстроки",
				params = { "s", "pattern", "init", "plain" },
			},
			{
				is_function = true,
				name = "format",
				description = "Форматирование строки",
				params = { "formatstring", "..." },
			},
			{
				is_function = true,
				name = "gmatch",
				description = "Итератор для поиска подстроки",
				params = { "s", "pattern" },
			},
			{
				is_function = true,
				name = "gsub",
				description = "Замена подстроки",
				params = { "s", "pattern", "repl", "n" },
			},
			{
				is_function = true,
				name = "len",
				description = "Длина строки",
				params = { "s" },
			},
			{
				is_function = true,
				name = "lower",
				description = "Преобразует строку в нижний регистр",
				params = { "s" },
			},
			{
				is_function = true,
				name = "match",
				description = "Поиск подстроки",
				params = { "s", "pattern", "init" },
			},
			{
				is_function = true,
				name = "reverse",
				description = "Переворачивает строку",
				params = { "s" },
			},
			{
				is_function = true,
				name = "sub",
				description = "Возвращает подстроку",
				params = { "s", "i", "j" },
			},
			{
				is_function = true,
				name = "upper",
				description = "Преобразует строку в верхний регистр",
				params = { "s" },
			},
		},
	},
	{
		is_module = true,
		name = "table",
		description = "Модуль для работы с таблицами",
		doc = {
			{
				is_function = true,
				name = "insert",
				description = "Добавляет элемент в таблицу",
				params = { "t", "pos", "value" },
			},
			{
				is_function = true,
				name = "maxn",
				description = "Возвращает максимальный индекс массива",
				params = { "t" },
			},
			{
				is_function = true,
				name = "remove",
				description = "Удаляет элемент из таблицы",
				params = { "t", "pos" },
			},
			{
				is_function = true,
				name = "sort",
				description = "Сортирует таблицу",
				params = { "t", "comp" },
			},
		},
	},
}

MDS = MONET_DPI_SCALE or 1
SOURCES_META_URL = "https://raw.githubusercontent.com/osp54/MonetBinder/main/sourcesmeta.json"
cfg = jsoncfg.load(cfg, "MonetBinder", ".json") or cfg
state = mimguiState()

doubleclickped.onDoubleClickedPed = function(ped, x, y)
	local res, id = sampGetPlayerIdByCharHandle(ped)

	if res then
		state.fastMenuPlayerId = id
		state.fastMenuPos = imgui.ImVec2(x, y)
		state.renderFastMenu[0] = true
	end
end

local function isGeneralSettingsChanged()
	return state.defaultDelayInput[0] ~= cfg.general.default_delay
		or ffi.string(state.nicknameInput) ~= cfg.general.nickname
		or ffi.string(state.fractionInput) ~= cfg.general.fraction
		or ffi.string(state.rankInput) ~= cfg.general.rank
		or state.rankNumberInput[0] + 1 ~= cfg.general.rank_number
end

imgui.OnInitialize(function()
	imgui.GetIO().IniFilename = nil
	fa.Init(14 * MDS)

	imgui.GetStyle():ScaleAllSizes(MDS)
	darkTheme()
end)

imgui.OnFrame(function()
	return state.renderMainMenu[0]
end, function(player)
	local screenX, screenY = getScreenResolution()

	imgui.SetNextWindowSize(imgui.ImVec2(700 * MDS, 400 * MDS), imgui.Cond.FirstUseEver)
	imgui.SetNextWindowPos(imgui.ImVec2(screenX / 2, screenY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
	imgui.Begin(u8("MonetBinder"), state.renderMainMenu)
	state.mainMenuMenuPos = imgui.GetWindowPos()

	imgui.BeginTabBar("##tabbar")
	if imgui.BeginTabItem(u8("Общие настройки")) then
		imutil.Setting(
			u8("Задержка"),
			u8("Задержка (мс): %d"):format(state.defaultDelayInput[0]),
			function()
				imgui.SetNextItemWidth(imgui.GetWindowWidth() - imgui.GetStyle().FramePadding.x * 2)
				imgui.InputInt("##defaultdelay", state.defaultDelayInput, 0)
			end
		)
		imgui.Separator()
		imutil.Setting(
			u8("Ваше РП имя"),
			u8("Ваше РП имя: %s"):format(ffi.string(state.nicknameInput)),
			function()
				imgui.SetNextItemWidth(imgui.GetWindowWidth() - imgui.GetStyle().FramePadding.x * 2)
				imgui.InputText("##nickname", state.nicknameInput, 256)
			end
		)
		imgui.Separator()
		imutil.Setting(
			u8("Ваша фракция"),
			u8("Ваша фракция: %s"):format(ffi.string(state.fractionInput)),
			function()
				imgui.SetNextItemWidth(imgui.GetWindowWidth() - imgui.GetStyle().FramePadding.x * 2)
				imgui.InputText("##fraction", state.fractionInput, 256)
			end
		)
		imgui.Separator()
		imutil.Setting(
			u8("Ваш ранг"),
			u8("Ваш ранг: %s (%d)"):format(ffi.string(state.rankInput), state.rankNumberInput[0] + 1),
			function()
				imgui.SetNextItemWidth(imgui.GetWindowWidth() - imgui.GetStyle().FramePadding.x * 2)
				imgui.InputText("##rank", state.rankInput, 256)
				imutil.CenterText(u8("Номер ранга:"))
				imgui.SetNextItemWidth(imgui.GetWindowWidth() - imgui.GetStyle().FramePadding.x * 2)
				imgui.Combo("##ranknumber", state.rankNumberInput, state.ImRanks, #state.ranks)
			end
		)
		local buttonlbl = u8(" Кнопка MonetBinder")
		if
			imutil.ToggleButtonIcon(
				fa.TOGGLE_ON .. buttonlbl,
				fa.TOGGLE_OFF .. buttonlbl,
				cfg.ui.monet_binder_button,
				imgui.ImVec2(imutil.GetMiddleButtonX(2), 30)
			)
		then
			cfg.ui.monet_binder_button = not cfg.ui.monet_binder_button
			state.monetBinderButton[0] = cfg.ui.monet_binder_button
		end
		imgui.SameLine()
		local buttonmovelbl = u8(" Перемещение кнопки")
		if
			imutil.ToggleButtonIcon(
				fa.TOGGLE_ON .. buttonmovelbl,
				fa.TOGGLE_OFF .. buttonmovelbl,
				state.monetBinderButtonMove,
				imgui.ImVec2(imutil.GetMiddleButtonX(2), 30)
			)
		then
			state.monetBinderButtonMove = not state.monetBinderButtonMove
		end

		if isGeneralSettingsChanged() then
			cfg.general.default_delay = state.defaultDelayInput[0]
			cfg.general.nickname = u8:decode(ffi.string(state.nicknameInput))
			cfg.general.rank = u8:decode(ffi.string(state.rankInput))
			cfg.general.rank_number = state.rankNumberInput[0] + 1
			jsoncfg.save(cfg, "MonetBinder", ".json")
		end
		if
			imgui.Button(
				fa.WAND_SPARKLES .. u8(" Заполнить автоматически"),
				imgui.ImVec2(imutil.GetMiddleButtonX(1), 30 * MDS)
			)
		then
			check_stats = true
			sampSendChat("/stats")
		end
		imgui.EndTabItem()
	end

	if imgui.BeginTabItem(u8("Профили, команды")) then
		imgui.BeginChild(
			"##profiles-vertical-choose",
			imgui.ImVec2((imgui.GetWindowWidth() * 0.35) - imgui.GetStyle().FramePadding.x * 2, 0),
			true
		)
		if imgui.Button(fa.CIRCLE_PLUS, imgui.ImVec2(imutil.GetMiddleButtonX(2), 30 * MDS)) then
			table.insert(commandloader.sources, {
				name = "profile" .. #commandloader.sources + 1,
				description = "",
				commands = {},
				enabled = true,
				filepath = getWorkingDirectory()
					.. PATH_SEPARATOR
					.. commandloader.dir
					.. PATH_SEPARATOR
					.. "profile"
					.. tostring(#commandloader.sources + 1)
					.. ".json",
			})
			state.selectedProfile = #commandloader.sources
			state.currentMsource = commandloader.toMimguiTable(commandloader.sources[state.selectedProfile])
		end
		imgui.SameLine()
		if imgui.Button(fa.GLOBE, imgui.ImVec2(imutil.GetMiddleButtonX(2), 30 * MDS)) then
			imgui.OpenPopup(u8("Профили, созданные другими игроками"))
		end
		if
			imgui.BeginPopupModal(
				u8("Профили, созданные другими игроками"),
				_,
				imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove
			)
		then
			imgui.SetWindowSizeVec2(imgui.ImVec2(700 * MDS, 400 * MDS))

			if
				imgui.Button(
					fa.ARROWS_ROTATE .. u8(" Перезагрузить список"),
					imgui.ImVec2(imutil.GetMiddleButtonX(1), 30 * MDS)
				)
			then
				state.sources_meta = nil
				state.sources_meta_loading = false
			end

			if state.sources_meta and state.sources_meta.error then
				imgui.SetCursorPosY(imgui.GetWindowHeight() / 2)
				imutil.CenterError(u8("Ошибка загрузки: %s"):format(state.sources_meta.error))
			end

			if state.sources_meta and not state.sources_meta.error then
				imgui.Columns(4, "##sources", true)
				imgui.Text(u8("Имя"))
				imgui.NextColumn()
				imgui.Text(u8("Описание"))
				imgui.NextColumn()
				imgui.Text(u8("Автор"))
				imgui.NextColumn()
				imgui.Text(u8("Действие"))
				imgui.NextColumn()
				imgui.Separator()
				for i, source in ipairs(state.sources_meta) do
					if not source.exsource then
						source.exsource = commandloader.findSourceByName(u8:decode(source.name)) or {}
					end
					if source.error then
						imgui.Columns(1)
						imutil.CenterError(u8("Ошибка загрузки: %s"):format(source.error))
						imgui.Columns(4, "##sources", true)
					elseif source.download_progress_percent then
						imgui.Columns(1)
						imgui.ProgressBar(source.download_progress_percent / 100, imgui.ImVec2(-1, 15 * MDS))
						imgui.Columns(4, "##sources", true)

						if source.downloaded_at + 5 < os.time() then
							source.downloaded_at = nil
							source.download_progress_percent = nil
							source.downloaded = nil
						end
					end
					imgui.Text(source.name)
					imgui.NextColumn()
					imgui.Text(source.description)
					imgui.NextColumn()
					imgui.Text(source.author)
					imgui.NextColumn()
					if
						imgui.Button(
							source.exsource.name and fa.ARROWS_ROTATE or fa.DOWNLOAD,
							imgui.ImVec2(imgui.GetColumnWidth() - imgui.GetStyle().FramePadding.x, 30 * MDS)
						)
					then
						local filename = source.download_link:match("([^/]+)$")
						local filepath = source.exsource.name and source.exsource.filepath
							or getWorkingDirectory()
								.. PATH_SEPARATOR
								.. commandloader.dir
								.. PATH_SEPARATOR
								.. filename

						util.downloadToFile(source.download_link, filepath, function(type, pos, total_size)
							if type == "downloading" then
								state.sources_meta[i].download_progress_percent = (pos / total_size) * 100
							elseif type == "error" then
								state.sources_meta[i].error = pos
							elseif type == "finished" then
								state.sources_meta[i].download_progress_percent = 100
								state.sources_meta[i].downloaded = true
								state.sources_meta[i].downloaded_at = os.time()

								commandloader.reload()
							end
						end)
					end
					imgui.NextColumn()
					imgui.Separator()
				end
				imgui.Columns(1)
			end

			if state.sources_meta_loading then
				imgui.SetCursorPosY(imgui.GetWindowHeight() / 2)
				imutil.CenterText(fa.SPINNER .. u8(" Загрузка..."))
			end

			if not state.sources_meta and not state.sources_meta_loading then
				state.sources_meta_loading = true

				local t = util.newThread(function(url)
					local requests = require("requests")

					local ok, res = pcall(requests.get, url)

					if not ok then
						return false, res
					end

					if res.status_code == 200 then
						return true, res.text
					else
						return false, res.status_code
					end
				end)

				t:run(SOURCES_META_URL)
				t:listen(function(res)
					state.sources_meta_loading = false

					local ok, data = pcall(decodeJson, res)
					if not ok then
						state.sources_meta = { error = data }
					else
						state.sources_meta = data
					end
				end, function(err)
					state.sources_meta = { error = err }
				end)
			end

			imgui.Dummy(imgui.ImVec2(0, 30 * MDS))
			imgui.SetCursorPosY(imgui.GetWindowHeight() - imgui.GetStyle().FramePadding.y - 30 * MDS)
			if imgui.Button(fa.XMARK .. u8(" Закрыть"), imgui.ImVec2(imutil.GetMiddleButtonX(1), 30 * MDS)) then
				imgui.CloseCurrentPopup()
			end
			imgui.EndPopup()
		end
		for i, source in pairs(commandloader.sources) do
			if
				imgui.Button(
					u8(source.name),
					imgui.ImVec2(imgui.GetWindowWidth() - imgui.GetStyle().FramePadding.x * 2, 30 * MDS)
				)
			then
				state.selectedProfile = i
				state.currentMsource = commandloader.toMimguiTable(source)
			end
		end
		imgui.EndChild()
		imgui.SameLine()
		imgui.BeginChild("##profile", imgui.ImVec2(0, 0), true)
		if state.selectedProfile == 0 then
			imgui.SetCursorPosY(imgui.GetWindowHeight() / 2)
			imutil.CenterText(u8("Выберите профиль"))

			imgui.EndChild()
			imgui.EndTabItem()
		end

		local source = commandloader.sources[state.selectedProfile]
		if source and state.currentMsource then
			if imgui.Button(fa.TRASH, imgui.ImVec2(imutil.GetMiddleButtonX(3), 30 * MDS)) then
				commandloader.removeSource(source)
				commandloader.sources[state.selectedProfile] = nil

				if #commandloader.sources > 0 then
					state.selectedProfile = 1
					state.currentMsource = commandloader.toMimguiTable(commandloader.sources[state.selectedProfile])
				else
					state.currentMsource = nil
					state.selectedProfile = 0
				end
			end
			if not state.currentMsource then
				imgui.EndChild()
				imgui.EndTabItem()
				return
			end

			imgui.SameLine()
			if imgui.Button(fa.FLOPPY_DISK, imgui.ImVec2(imutil.GetMiddleButtonX(3), 30 * MDS)) then
				commandloader.sources[state.selectedProfile] = commandloader.fromMimguiTable(state.currentMsource)
				commandloader.saveSource(commandloader.sources[state.selectedProfile])
				commandloader.reload()
			end
			imgui.SameLine()
			if
				imutil.ToggleButtonIcon(
					fa.TOGGLE_ON,
					fa.TOGGLE_OFF,
					state.currentMsource.enabled[0],
					imgui.ImVec2(imutil.GetMiddleButtonX(3), 30 * MDS)
				)
			then
				state.currentMsource.enabled[0] = not state.currentMsource.enabled[0]
			end
			imgui.Separator()
			imutil.Setting(u8("Имя"), u8("Имя: %s"):format(ffi.string(state.currentMsource.name)), function()
				imgui.SetNextItemWidth(imgui.GetWindowWidth() - imgui.GetStyle().FramePadding.x * 2)
				imgui.InputText("##name", state.currentMsource.name, 256)
			end)
			imgui.Separator()
			imutil.Setting(
				u8("Описание"),
				imutil.shortifyText(u8("Описание: %s"):format(ffi.string(state.currentMsource.description))),
				function()
					imgui.SetWindowSizeVec2(imgui.ImVec2(450 * MDS, 400 * MDS))
					imgui.SetNextItemWidth(imgui.GetWindowWidth() - imgui.GetStyle().FramePadding.x * 2)
					imgui.InputTextMultiline(
						"##description",
						state.currentMsource.description,
						256,
						imgui.ImVec2(0, imgui.GetWindowHeight() - 100 * MDS) -- ch
					)
				end
			)
			imgui.BeginChild("##commands", imgui.ImVec2(0, 0), true)
			if
				imgui.Button(
					fa.CIRCLE_PLUS .. u8(" Создать команду"),
					imgui.ImVec2(imutil.GetMiddleButtonX(1), 30 * MDS)
				)
			then
				table.insert(state.currentMsource.commands, {
					name = imgui.new.char[256]("cmd" .. #state.currentMsource.commands + 1),
					description = imgui.new.char[256](),
					text = imgui.new.char[1024](),
					enabled = imgui.new.bool(true),
					params = {},
				})
			end
			imgui.Columns(3, "##commands", true)
			imgui.Text(u8("Команда"))
			imgui.NextColumn()
			imgui.Text(u8("Описание"))
			imgui.NextColumn()
			imgui.Text(u8("Действие"))
			imgui.NextColumn()
			imgui.Separator()
			for i, command in pairs(state.currentMsource.commands) do
				local cmdname = ffi.string(command.name)
				imgui.Text("/" .. cmdname)
				imgui.NextColumn()
				imgui.Text(imutil.shortifyText(ffi.string(command.description), imgui.GetColumnWidth()))
				imgui.NextColumn()
				if
					imutil.ToggleButtonIcon(
						fa.TOGGLE_ON .. "##" .. cmdname,
						fa.TOGGLE_OFF .. "##" .. cmdname,
						command.enabled[0],
						imgui.ImVec2(imutil.GetMiddleColumnX(3), 30 * MDS)
					)
				then
					command.enabled[0] = not command.enabled[0]
				end
				imgui.SameLine()
				if imgui.Button(fa.TRASH .. "##" .. cmdname, imgui.ImVec2(imutil.GetMiddleColumnX(3), 30 * MDS)) then
					table.remove(state.currentMsource.commands, i)
				end
				imgui.SameLine()
				if imgui.Button(fa.PEN .. "##" .. cmdname, imgui.ImVec2(imutil.GetMiddleColumnX(3), 30 * MDS)) then
					state.currentCommand = i
					imgui.OpenPopup(u8("Редактирование команды"))
				end
				imgui.NextColumn()
				imgui.Separator()
			end
			if
				imgui.BeginPopupModal(
					u8("Редактирование команды"),
					_,
					imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove
				)
			then
				local command = state.currentMsource.commands[state.currentCommand]

				imgui.SetWindowSizeVec2(imgui.ImVec2(700 * MDS, 400 * MDS))
				if util.isEmpty(ffi.string(command.name)) then
					imutil.CenterError(u8(commandloader.errorDescriptions[2]))
				end
				imutil.Setting(
					u8("Название"),
					u8("Название: %s"):format(ffi.string(command.name)),
					function()
						imgui.SetNextItemWidth(imgui.GetWindowWidth() - imgui.GetStyle().FramePadding.x * 2)
						imgui.InputText("##commandname", command.name, 256)
					end
				)
				imgui.Separator()
				imutil.Setting(
					u8("Описание"),
					u8("Описание: %s"):format(ffi.string(command.description)),
					function()
						imgui.SetNextItemWidth(imgui.GetWindowWidth() - imgui.GetStyle().FramePadding.x * 2)
						imgui.InputText("##commanddescription", command.description, 256)
					end
				)
				imgui.Separator()

				if util.isEmpty(ffi.string(command.text)) then
					imutil.CenterError(u8(commandloader.errorDescriptions[3]))
				end
				imutil.Setting(
					u8("Текст"),
					imutil.shortifyText(u8("Текст: %s"):format(ffi.string(command.text):gsub("\n", ""))),
					function()
						imgui.SetWindowSizeVec2(imgui.ImVec2(600 * MDS, 300 * MDS))

						imgui.SetNextItemWidth(imgui.GetWindowWidth() - imgui.GetStyle().FramePadding.x * 2)
						imgui.InputTextMultiline(
							"##commandtext",
							command.text,
							1024,
							imgui.ImVec2(0, imgui.GetWindowHeight() - 70 - imgui.GetStyle().FramePadding.y * 2)
						)

						imgui.SetCursorPosY(imgui.GetWindowHeight() - 30 * MDS - imgui.GetStyle().FramePadding.y * 2)
						if
							imgui.Button(
								fa.TAGS .. u8(" Переменные/Функции"),
								imgui.ImVec2(imutil.GetMiddleButtonX(2), 30 * MDS)
							)
						then
							imgui.OpenPopup(u8("Переменные/Функции"))
						end

						if
							imgui.BeginPopupModal(
								u8("Переменные/Функции"),
								_,
								imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove
							)
						then
							imgui.SetWindowSizeVec2(imgui.ImVec2(700 * MDS, 400 * MDS))
							imutil.CenterText(
								u8(
									"Переменные, которые можно использовать в тексте команды:"
								)
							)
							imgui.Separator()
							for k, v in pairs(cfg.general) do
								imgui.Text(u8("~{%s}~ -- %s"):format(k, u8(v)))
								imgui.Separator()
							end

							imutil.CenterText(
								u8(
									"Функции, которые можно использовать в тексте команды:"
								)
							)
							imgui.Separator()
							for i, doc in ipairs(commandloader.env_docs) do
								local params = #doc.params > 0 and "(" .. table.concat(doc.params, ", ") .. ")" or "()"
								imgui.Text(u8("~{%s%s}~ %s"):format(doc.name, u8(params), u8(doc.description)))
								imgui.Separator()
							end

							if imgui.CollapsingHeader(u8("Доступные функции Lua")) then
								if
									imgui.Button(
										fa.LINK .. u8(" Открыть документацию Lua"),
										imgui.ImVec2(imutil.GetMiddleButtonX(1), 20 * MDS)
									)
								then
									util.openLink("https://www.lua.org/manual/5.1/")
								end
								function processAllowedLuaDoc(data, prefix)
									for i, v in ipairs(data) do
										local fullKey = prefix and (prefix .. "." .. v.name) or v.name
										if v.is_const then
											imgui.Text(u8("~{%s}~ -- %s"):format(fullKey, u8(v.description)))
											imgui.Separator()
										end

										if v.is_function then
											local params = "(" .. table.concat(v.params or {}, ", ") .. ")"
											imgui.Text(u8("~{%s%s}~ %s"):format(fullKey, params, u8(v.description)))
											imgui.Separator()
										end

										if v.is_module then
											imutil.CenterText(u8("Модуль: %s"):format(fullKey))
											imutil.CenterText(u8(v.description))
											processAllowedLuaDoc(v.doc, fullKey)
										end
									end
								end
								processAllowedLuaDoc(allowedLuaDoc)
							end

							imgui.Dummy(imgui.ImVec2(0, 30 * MDS))
							--imgui.SetCursorPosY(imgui.GetWindowHeight() - imgui.GetFrameHeightWithSpacing())
							imgui.SetCursorPosY(
								imgui.GetWindowHeight()
									- imgui.GetStyle().FramePadding.y
									- 30 * MDS
									+ imgui.GetScrollY()
							)
							if
								imgui.Button(
									fa.XMARK .. u8(" Закрыть"),
									imgui.ImVec2(imutil.GetMiddleButtonX(1), 30 * MDS)
								)
							then
								imgui.CloseCurrentPopup()
							end
							imgui.EndPopup()
						end
						imgui.SameLine()
						if
							imgui.Button(
								fa.XMARK .. u8(" Закрыть"),
								imgui.ImVec2(imutil.GetMiddleButtonX(2), 30 * MDS)
							)
						then
							imgui.CloseCurrentPopup()
						end
					end,
					false
				)

				imutil.CenterText(u8("Параметры"))
				imgui.Separator()
				imgui.Columns(4, "##params", true)
				imgui.Text(u8("Параметр"))
				imgui.NextColumn()
				imgui.Text(u8("Тип"))
				imgui.NextColumn()
				imgui.Text(u8("По умолчанию"))
				imgui.NextColumn()
				imgui.Text(u8("Действие"))
				imgui.NextColumn()
				imgui.Separator()

				for i, param in pairs(command.params) do
					if not param.ImTypes then
						param.types = {}
						param.selectedType = imgui.new.int(0)
						local i = 0
						for k, v in pairs(commandloader.typeProcessor) do
							table.insert(param.types, k)
							if ffi.string(param.type) == k then
								param.selectedType = imgui.new.int(i)
							end
							i = i + 1
						end
						param.ImTypes = imgui.new["const char*"][#param.types](param.types)
					end
					imgui.SetNextItemWidth(imgui.GetColumnWidth() - imgui.GetStyle().FramePadding.x * 2)
					imgui.InputText("##paramname" .. i, param.name, 256)
					imgui.NextColumn()

					imgui.SetNextItemWidth(imgui.GetColumnWidth() - imgui.GetStyle().FramePadding.x * 2)
					imgui.Combo("##paramtype" .. i, param.selectedType, param.ImTypes, #param.types)
					imgui.NextColumn()

					imgui.SetNextItemWidth(imgui.GetColumnWidth() - imgui.GetStyle().FramePadding.x * 2)
					imgui.InputText("##paramdefault" .. i, param.default, 256)
					imgui.NextColumn()
					if
						imgui.Button(
							fa.TRASH .. "##param" .. i,
							imgui.ImVec2(imgui.GetColumnWidth() - imgui.GetStyle().FramePadding.x * 2, 30 * MDS)
						)
					then
						table.remove(command.params, i)
					end
					imgui.NextColumn()
					imgui.Separator()
				end
				imgui.Columns(1)
				if
					imgui.Button(
						fa.CIRCLE_PLUS .. u8(" Добавить параметр"),
						imgui.ImVec2(imutil.GetMiddleButtonX(1), 30 * MDS)
					)
				then
					table.insert(command.params, {
						name = imgui.new.char[256]("param" .. #command.params + 1),
						type = "string",
						default = imgui.new.char[256](),
					})
				end

				imgui.Dummy(imgui.ImVec2(0, 30 * MDS))
				imgui.SetCursorPosY(imgui.GetWindowHeight() - imgui.GetStyle().FramePadding.y - 30 + imgui.GetScrollY())
				if imgui.Button(fa.FLOPPY_DISK, imgui.ImVec2(imutil.GetMiddleButtonX(1), 30 * MDS)) then
					if not util.isEmpty(ffi.string(command.name)) and not util.isEmpty(ffi.string(command.text)) then
						for _, param in pairs(command.params) do
							param.type = param.types[param.selectedType[0] + 1]
							param.required = imgui.new.bool(util.isEmpty(ffi.string(param.default)))
						end

						commandloader.sources[state.selectedProfile] =
							commandloader.fromMimguiTable(state.currentMsource)
						commandloader.saveSource(commandloader.sources[state.selectedProfile])
						commandloader.reload()
						android:showToast(u8("Команда сохранена"), 1)
						imgui.CloseCurrentPopup()
					else
						android:showToast(u8("Заполните все поля"), 1)
					end
				end
				imgui.EndPopup()
			end
			imgui.EndChild()
		end
		imgui.EndChild()
		imgui.EndTabItem()
	end

	imgui.End()
end)

imgui.OnFrame(function()
	return state.monetBinderButton[0]
end, function(player)
	local pos = imgui.ImVec2(cfg.ui.monet_binder_button_pos.x, cfg.ui.monet_binder_button_pos.y)
	local size = imgui.ImVec2(cfg.ui.monet_binder_button_size.x, cfg.ui.monet_binder_button_size.y)
	res, pos, size =
		imutil.BackgroundButton(fa.TERMINAL, state.monetBinderButton, pos, size, nil, state.monetBinderButtonMove)

	if res then
		state.renderMainMenu[0] = not state.renderMainMenu[0]
	end

	cfg.ui.monet_binder_button_pos.x = pos.x
	cfg.ui.monet_binder_button_pos.y = pos.y

	cfg.ui.monet_binder_button_size.x = size.x
	cfg.ui.monet_binder_button_size.y = size.y
end)

imgui.OnFrame(function()
	return true
end, function(player)
	for i, menu in ipairs(state.menus) do
		if menu.render[0] then
			imgui.SetNextWindowSize(imgui.ImVec2(200 * MDS, 125 * MDS), imgui.Cond.FirstUseEver)
			local screenX, screenY = getScreenResolution()

			imgui.SetNextWindowPos(
				imgui.ImVec2(screenX / 2, screenY - 100),
				imgui.Cond.FirstUseEver,
				imgui.ImVec2(0.5, 0.5)
			)
			imgui.Begin(u8(menu.name .. "##" .. i), menu.render)
			imgui.Separator()
			for i, choice in ipairs(menu.choices) do
				local middleX = imutil.GetMiddleButtonX(2)

				if imgui.Button(u8(choice.name), imgui.ImVec2(middleX, 30 * MDS)) then
					lua_thread.create(function()
						local i = 1
						for line in string.gmatch(choice.text, "[^\r\n]+") do
							if state.waitm then
								wait(state.waitm)
							elseif i > 1 then
								wait(cfg.general.default_delay)
							end

							if not util.isEmpty(line) then
								sampProcessChatInput(line)
							end

							i = i + 1
						end
					end)
					menu.render[0] = false
					table.remove(state.menus, i)
				end

				if i % 2 ~= 0 then
					imgui.SameLine()
				end
			end
			imgui.End()
		end
	end
end)

imgui.OnFrame(function()
	return state.renderFastMenu[0]
end, function(player)
	if state.fastMenuPlayerId and sampIsPlayerConnected(state.fastMenuPlayerId) then
		imgui.SetNextWindowSize(imgui.ImVec2(400 * MDS, 250 * MDS), imgui.Cond.FirstUseEver)
		imgui.SetNextWindowPos(
			imgui.ImVec2(state.fastMenuPos.x, state.fastMenuPos.y + 250 / 2 * MDS),
			imgui.Cond.FirstUseEver,
			imgui.ImVec2(0.5, 0.5)
		)

		local nickname = sampGetPlayerNickname(state.fastMenuPlayerId)
		imgui.Begin(u8("Действия над игроком ") .. nickname, state.renderFastMenu)
		if imgui.BeginTabBar("##fastmenu") then
			for _, source in pairs(commandloader.sources) do
				if source.enabled then
					local filtered = {}
					for _, command in pairs(source.commands) do
						if command.enabled and #command.params > 0 and command.params[1].type == "player" then
							table.insert(filtered, command)
						end
					end

					local middleX = imutil.GetMiddleButtonX(2)
					if #filtered > 0 then
						if imgui.BeginTabItem(u8(source.name)) then
							for i, command in ipairs(filtered) do
								if imutil.ButtonWrappedTextCenter(("/%s\n%s"):format(u8(command.name), u8(command.description)), imgui.ImVec2(middleX, 40 * MDS)) then
									print(command.name)
									sampProcessChatInput("/"..command.name.." "..state.fastMenuPlayerId)
								end

								if i % 2 ~= 0 then
									imgui.SameLine()
								end
							end
							imgui.EndTabItem()
						end
					end
				end
			end
			imgui.EndTabBar()
		end
		imgui.End()
	end
end)

function main()
	android:looperPrepare()
	if not isSampLoaded() or not isSampfuncsLoaded() then
		return
	end
	while not isSampAvailable() do
		wait(0)
	end
	while not sampIsLocalPlayerSpawned() do
		wait(0)
	end

	cfg.general.nickname = cfg.general.nickname ~= "" and cfg.general.nickname
		or util.TranslateNick(sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))))

	if cfg.general.rank == "" or cfg.general.rank == nil then
		check_stats = true
		sampSendChat("/stats")
	end
	commandloader.load()
	commandloader.registerCommands()

	sampRegisterChatCommand("mb", function()
		state.renderMainMenu[0] = not state.renderMainMenu[0]
	end)

	android:showToast(
		u8("MonetBinder загружен. %s шаблонов. %s команд."):format(
			commandloader.sourceCount(),
			commandloader.commandCount()
		),
		2
	)

	while true do
		wait(0)
	end
end

require("samp.events").onShowDialog = function(dialogid, style, title, button1, button2, text)
	if dialogid == 235 and check_stats then
		if text:find("{FFFFFF}Организация: {B83434}%[(.-)]") then
			cfg.general.fraction = text:match("{FFFFFF}Организация: {B83434}%[(.-)]")
			state.fractionInput = imgui.new.char[256](u8(cfg.general.fraction))
		end
		if text:find("{FFFFFF}Должность: {B83434}(.+)%((%d+)%)") then
			cfg.general.rank, cfg.general.rank_number =
				text:match("{FFFFFF}Должность: {B83434}(.+)%((%d+)%)(.+)Уровень розыска")
			state.rankInput = imgui.new.char[256](u8(cfg.general.rank))
			state.rankNumberInput = imgui.new.int(cfg.general.rank_number - 1)
		else
			sampAddChatMessage(
				"[MonetBinder] Не удалось обнаружить вашу должность.",
				-1
			)
		end

		sampSendDialogResponse(235, 0, 0, 0)
		check_stats = false
		return false
	end
end

function generateUsage(cmd, params)
	local usage = "/" .. cmd
	for _, v in ipairs(params) do
		local bracket = v.required and "<" or "["
		usage = usage .. " " .. bracket .. v.name .. (not v.required and "]" or ">")
	end
	return usage
end

---Author: Chapo
function darkTheme()
	imgui.SwitchContext()
	--==[ STYLE ]==--
	imgui.GetStyle().WindowPadding = imgui.ImVec2(5, 5)
	imgui.GetStyle().FramePadding = imgui.ImVec2(5, 5)
	imgui.GetStyle().ItemSpacing = imgui.ImVec2(5, 5)
	imgui.GetStyle().ItemInnerSpacing = imgui.ImVec2(2, 2)
	imgui.GetStyle().TouchExtraPadding = imgui.ImVec2(0, 0)
	imgui.GetStyle().IndentSpacing = 0
	imgui.GetStyle().ScrollbarSize = 10
	imgui.GetStyle().GrabMinSize = 10

	--==[ BORDER ]==--
	imgui.GetStyle().WindowBorderSize = 1
	imgui.GetStyle().ChildBorderSize = 1
	imgui.GetStyle().PopupBorderSize = 1
	imgui.GetStyle().FrameBorderSize = 1
	imgui.GetStyle().TabBorderSize = 1

	--==[ ROUNDING ]==--
	imgui.GetStyle().WindowRounding = 5
	imgui.GetStyle().ChildRounding = 5
	imgui.GetStyle().FrameRounding = 5
	imgui.GetStyle().PopupRounding = 5
	imgui.GetStyle().ScrollbarRounding = 5
	imgui.GetStyle().GrabRounding = 5
	imgui.GetStyle().TabRounding = 5

	--==[ ALIGN ]==--
	imgui.GetStyle().WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
	imgui.GetStyle().ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
	imgui.GetStyle().SelectableTextAlign = imgui.ImVec2(0.5, 0.5)

	--==[ COLORS ]==--
	imgui.GetStyle().Colors[imgui.Col.Text] = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
	imgui.GetStyle().Colors[imgui.Col.TextDisabled] = imgui.ImVec4(0.50, 0.50, 0.50, 1.00)
	imgui.GetStyle().Colors[imgui.Col.WindowBg] = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
	imgui.GetStyle().Colors[imgui.Col.ChildBg] = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
	imgui.GetStyle().Colors[imgui.Col.PopupBg] = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
	imgui.GetStyle().Colors[imgui.Col.Border] = imgui.ImVec4(0.25, 0.25, 0.26, 0.54)
	imgui.GetStyle().Colors[imgui.Col.BorderShadow] = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
	imgui.GetStyle().Colors[imgui.Col.FrameBg] = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
	imgui.GetStyle().Colors[imgui.Col.FrameBgHovered] = imgui.ImVec4(0.25, 0.25, 0.26, 1.00)
	imgui.GetStyle().Colors[imgui.Col.FrameBgActive] = imgui.ImVec4(0.25, 0.25, 0.26, 1.00)
	imgui.GetStyle().Colors[imgui.Col.TitleBg] = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
	imgui.GetStyle().Colors[imgui.Col.TitleBgActive] = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
	imgui.GetStyle().Colors[imgui.Col.TitleBgCollapsed] = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
	imgui.GetStyle().Colors[imgui.Col.MenuBarBg] = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
	imgui.GetStyle().Colors[imgui.Col.ScrollbarBg] = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
	imgui.GetStyle().Colors[imgui.Col.ScrollbarGrab] = imgui.ImVec4(0.00, 0.00, 0.00, 1.00)
	imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(0.41, 0.41, 0.41, 1.00)
	imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabActive] = imgui.ImVec4(0.51, 0.51, 0.51, 1.00)
	imgui.GetStyle().Colors[imgui.Col.CheckMark] = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
	imgui.GetStyle().Colors[imgui.Col.SliderGrab] = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
	imgui.GetStyle().Colors[imgui.Col.SliderGrabActive] = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
	imgui.GetStyle().Colors[imgui.Col.Button] = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
	imgui.GetStyle().Colors[imgui.Col.ButtonHovered] = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
	imgui.GetStyle().Colors[imgui.Col.ButtonActive] = imgui.ImVec4(0.41, 0.41, 0.41, 1.00)
	imgui.GetStyle().Colors[imgui.Col.Header] = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
	imgui.GetStyle().Colors[imgui.Col.HeaderHovered] = imgui.ImVec4(0.20, 0.20, 0.20, 1.00)
	imgui.GetStyle().Colors[imgui.Col.HeaderActive] = imgui.ImVec4(0.47, 0.47, 0.47, 1.00)
	imgui.GetStyle().Colors[imgui.Col.Separator] = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
	imgui.GetStyle().Colors[imgui.Col.SeparatorHovered] = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
	imgui.GetStyle().Colors[imgui.Col.SeparatorActive] = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
	imgui.GetStyle().Colors[imgui.Col.ResizeGrip] = imgui.ImVec4(1.00, 1.00, 1.00, 0.25)
	imgui.GetStyle().Colors[imgui.Col.ResizeGripHovered] = imgui.ImVec4(1.00, 1.00, 1.00, 0.67)
	imgui.GetStyle().Colors[imgui.Col.ResizeGripActive] = imgui.ImVec4(1.00, 1.00, 1.00, 0.95)
	imgui.GetStyle().Colors[imgui.Col.Tab] = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
	imgui.GetStyle().Colors[imgui.Col.TabHovered] = imgui.ImVec4(0.28, 0.28, 0.28, 1.00)
	imgui.GetStyle().Colors[imgui.Col.TabActive] = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
	imgui.GetStyle().Colors[imgui.Col.TabUnfocused] = imgui.ImVec4(0.07, 0.10, 0.15, 0.97)
	imgui.GetStyle().Colors[imgui.Col.TabUnfocusedActive] = imgui.ImVec4(0.14, 0.26, 0.42, 1.00)
	imgui.GetStyle().Colors[imgui.Col.PlotLines] = imgui.ImVec4(0.61, 0.61, 0.61, 1.00)
	imgui.GetStyle().Colors[imgui.Col.PlotLinesHovered] = imgui.ImVec4(1.00, 0.43, 0.35, 1.00)
	imgui.GetStyle().Colors[imgui.Col.PlotHistogram] = imgui.ImVec4(0.90, 0.70, 0.00, 1.00)
	imgui.GetStyle().Colors[imgui.Col.PlotHistogramHovered] = imgui.ImVec4(1.00, 0.60, 0.00, 1.00)
	imgui.GetStyle().Colors[imgui.Col.TextSelectedBg] = imgui.ImVec4(1.00, 0.00, 0.00, 0.35)
	imgui.GetStyle().Colors[imgui.Col.DragDropTarget] = imgui.ImVec4(1.00, 1.00, 0.00, 0.90)
	imgui.GetStyle().Colors[imgui.Col.NavHighlight] = imgui.ImVec4(0.26, 0.59, 0.98, 1.00)
	imgui.GetStyle().Colors[imgui.Col.NavWindowingHighlight] = imgui.ImVec4(1.00, 1.00, 1.00, 0.70)
	imgui.GetStyle().Colors[imgui.Col.NavWindowingDimBg] = imgui.ImVec4(0.80, 0.80, 0.80, 0.20)
	imgui.GetStyle().Colors[imgui.Col.ModalWindowDimBg] = imgui.ImVec4(0.00, 0.00, 0.00, 0.70)
end

function onScriptTerminate(script, quitGame)
	if script == thisScript() then
		jsoncfg.save(cfg, "MonetBinder", ".json")
	end
end
