import { application } from "./application";

// Import and register all Stimulus controllers
import HelloController from "./hello_controller";
import AudioRecorderController from "./audio_recorder_controller";

application.register("hello", HelloController);
application.register("audio-recorder", AudioRecorderController);