import Quickshell 1.0
import Quickshell.Io 1.0
import QtQuick

QtObject {
    Component.onCompleted: {
        console.log("Iniciando prueba de proceso...")
        var process = Quickshell.Io.Process.create({
            command: ["/usr/bin/ls", "/tmp"],
            stdout: "/tmp/quickshell_ls_test.txt"
        })
        
        process.onFinished.connect(function() {
            console.log("Proceso terminado con código: " + process.exitCode)
            Qt.quit()
        })
        
        process.onError.connect(function() {
            console.log("Error en el proceso: " + process.errorString)
            Qt.quit()
        })
    }
}
