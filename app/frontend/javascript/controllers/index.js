import { application } from "./application";

// Import and register all Stimulus controllers
import HelloController from "./hello_controller";

application.register("hello", HelloController);