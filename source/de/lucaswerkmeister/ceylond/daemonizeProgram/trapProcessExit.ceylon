import java.lang {
    JClass=Class,
    SecurityManager,
    System,
    Thread,
    ThreadGroup
}
import java.io {
    FileDescriptor
}
import java.net {
    InetAddress
}
import java.security {
    Permission
}

"Run the specified [[trap]] function when [[process.exit]] is called.
 The process will actually exit iff the function does not throw.

 If multiple traps are installed, they are run in reverse order
 (most recently installed trap first),
 until one of them throws."
native void trapProcessExit(void trap(Integer exitCode));

native ("jvm") SecurityManager allowEverything = object extends SecurityManager() {
    shared actual void checkAccept(String host, Integer port) {}
    shared actual void checkAccess(Thread t) {}
    shared actual void checkAccess(ThreadGroup g) {}
    shared actual void checkAwtEventQueueAccess() {}
    shared actual void checkConnect(String host, Integer port) {}
    shared actual void checkConnect(String host, Integer port, Object context) {}
    shared actual void checkCreateClassLoader() {}
    shared actual void checkDelete(String file) {}
    shared actual void checkExec(String cmd) {}
    shared actual void checkExit(Integer code) {}
    shared actual void checkLink(String lib) {}
    shared actual void checkListen(Integer port) {}
    shared actual void checkMemberAccess(JClass<out Object> clazz, Integer which) {}
    shared actual void checkMulticast(InetAddress maddr) {}
    shared actual void checkMulticast(InetAddress maddr, Byte ttl) {}
    shared actual void checkPackageAccess(String pkg) {}
    shared actual void checkPackageDefinition(String pkg) {}
    shared actual void checkPermission(Permission perm) {}
    shared actual void checkPermission(Permission perm, Object context) {}
    shared actual void checkPrintJobAccess() {}
    shared actual void checkPropertiesAccess() {}
    shared actual void checkPropertyAccess(String key) {}
    shared actual void checkRead(FileDescriptor fd) {}
    shared actual void checkRead(String file) {}
    shared actual void checkRead(String file, Object context) {}
    shared actual void checkSecurityAccess(String target) {}
    shared actual void checkSetFactory() {}
    shared actual void checkSystemClipboardAccess() {}
    shared actual Boolean checkTopLevelWindow(Object window) => true;
    shared actual void checkWrite(FileDescriptor fd) {}
    shared actual void checkWrite(String file) {}
};

suppressWarnings ("deprecation")
native ("jvm") void trapProcessExit(void trap(Integer exitCode)) {
    value securityManager = System.securityManager else allowEverything;
    System.securityManager = object extends SecurityManager() {
        shared actual void checkExit(Integer status) {
            trap(status);
            securityManager.checkExit(status);
        }
        checkAccept = securityManager.checkAccept;
        shared actual void checkAccess(Thread t) => securityManager.checkAccess(t);
        shared actual void checkAccess(ThreadGroup g) => securityManager.checkAccess(g);
        checkAwtEventQueueAccess = securityManager.checkAwtEventQueueAccess;
        shared actual void checkConnect(String host, Integer port) => securityManager.checkConnect(host, port);
        shared actual void checkConnect(String host, Integer port, Object context) => securityManager.checkConnect(host, port, context);
        checkCreateClassLoader = securityManager.checkCreateClassLoader;
        checkDelete = securityManager.checkDelete;
        checkExec = securityManager.checkExec;
        checkLink = securityManager.checkLink;
        checkListen = securityManager.checkListen;
        //checkMemberAccess = securityManager.checkMemberAccess;
        shared actual void checkMemberAccess(JClass<out Object> clazz, Integer which) => securityManager.checkMemberAccess(clazz, which);
        shared actual void checkMulticast(InetAddress maddr) => securityManager.checkMulticast(maddr);
        shared actual void checkMulticast(InetAddress maddr, Byte ttl) => securityManager.checkMulticast(maddr, ttl);
        checkPackageAccess = securityManager.checkPackageAccess;
        checkPackageDefinition = securityManager.checkPackageDefinition;
        shared actual void checkPermission(Permission perm) => securityManager.checkPermission(perm);
        shared actual void checkPermission(Permission perm, Object context) => securityManager.checkPermission(perm, context);
        checkPrintJobAccess = securityManager.checkPrintJobAccess;
        checkPropertiesAccess = securityManager.checkPropertiesAccess;
        checkPropertyAccess = securityManager.checkPropertyAccess;
        shared actual void checkRead(FileDescriptor fd) => securityManager.checkRead(fd);
        shared actual void checkRead(String file) => securityManager.checkRead(file);
        shared actual void checkRead(String file, Object context) => securityManager.checkRead(file, context);
        checkSecurityAccess = securityManager.checkSecurityAccess;
        checkSetFactory = securityManager.checkSetFactory;
        checkSystemClipboardAccess = securityManager.checkSystemClipboardAccess;
        checkTopLevelWindow = securityManager.checkTopLevelWindow;
        shared actual void checkWrite(FileDescriptor fd) => securityManager.checkWrite(fd);
        shared actual void checkWrite(String file) => securityManager.checkWrite(file);
        inCheck => securityManager.inCheck;
        securityContext => securityManager.securityContext;
        threadGroup => securityManager.threadGroup;
    };
}

native ("js") void trapProcessExit(void trap(Integer exitCode)) {
    dynamic {
        eval("(function(process, trap) {
                  const exit = process.exit;
                  process.exit = function(code) {
                      trap(code);
                      exit(code);
                  };
              })")(process, trap);
    }
}
