import esbuild from "esbuild";
import * as sass from "sass";
import fs from "fs";
import path from "path";

const isWatch = process.argv.includes("--watch");

// Plugin de esbuild para marcar las importaciones de GJS/AGS como externas
const externalResourcesPlugin = {
    name: "external-resources",
    setup(build) {
        build.onResolve({ filter: /^(resource:\/\/|gi:\/\/)/ }, (args) => {
            return { path: args.path, external: true };
        });
    },
};

async function buildJs() {
    try {
        await esbuild.build({
            entryPoints: ["src/main.ts"],
            bundle: true,
            outfile: "config.js",
            format: "esm",
            minify: false,
            sourcemap: "inline",
            platform: "neutral",
            plugins: [externalResourcesPlugin],
        });
        console.log("✓ JS compilado exitosamente a config.js");
    } catch (err) {
        console.error("✗ Error al compilar JS:", err);
    }
}

function buildCss() {
    try {
        const scssPath = "src/infrastructure/scss/main.scss";
        if (!fs.existsSync(scssPath)) {
            // Si el archivo no existe aún, creamos el directorio y un archivo vacío temporal
            const dir = path.dirname(scssPath);
            if (!fs.existsSync(dir)) {
                fs.mkdirSync(dir, { recursive: true });
            }
            fs.writeFileSync(scssPath, "/* Estilos de AGS */");
        }
        
        const result = sass.compile(scssPath, {
            style: "expanded",
        });
        fs.writeFileSync("style.css", result.css);
        console.log("✓ SCSS compilado exitosamente a style.css");
    } catch (err) {
        console.error("✗ Error al compilar SCSS:", err);
    }
}

async function start() {
    // Asegurarse de que el directorio src existe
    if (!fs.existsSync("src")) {
        fs.mkdirSync("src", { recursive: true });
    }

    await buildJs();
    buildCss();

    if (isWatch) {
        console.log("Observando cambios en src/...");
        fs.watch("src", { recursive: true }, async (eventType, filename) => {
            if (!filename) return;
            
            if (filename.endsWith(".ts") || filename.endsWith(".js")) {
                console.log(`[Cambio JS/TS] ${filename} - Recompilando...`);
                await buildJs();
            } else if (filename.endsWith(".scss")) {
                console.log(`[Cambio SCSS] ${filename} - Recompilando...`);
                buildCss();
            }
        });
    }
}

start().catch((err) => {
    console.error("Error en el proceso de compilación:", err);
    process.exit(1);
});
