import App from "resource:///com/github/Aylur/ags/app.js";
import { Bar } from "./adapters/primary/ui/bar/Bar.js";

// Aplicar estilos SCSS compilados a style.css
const cssPath = App.configDir + "/style.css";
App.applyCss(cssPath);

// Inicializar la configuración de la ventana principal de AGS
App.config({
    style: cssPath,
    windows: [
        Bar(0), // Se crea la barra en el monitor 0
    ],
});
