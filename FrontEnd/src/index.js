import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
// Optionally, if you have a reportWebVitals file, you can import it; otherwise, you can omit it
import reportWebVitals from "./reportWebVitals";

const root = ReactDOM.createRoot(document.getElementById("root"));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);

// If you want to measure performance in your app, pass a function to log results (or send to an analytics endpoint)
reportWebVitals();
