import { Application } from "@hotwired/stimulus";
import PresentationController from "../javascript/controllers/presentation_controller";

// Create a separate Stimulus application instance for the presentation
const application = Application.start();
application.register("presentation", PresentationController);