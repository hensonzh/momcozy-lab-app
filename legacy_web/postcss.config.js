import path from "node:path";
import { fileURLToPath } from "node:url";

const legacyWebRoot = path.dirname(fileURLToPath(import.meta.url));

export default {
  plugins: {
    tailwindcss: {
      config: path.join(legacyWebRoot, "tailwind.config.ts"),
    },
    autoprefixer: {},
  },
};
