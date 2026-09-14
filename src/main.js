const { invoke } = window.__TAURI__.core;

const btn = document.getElementById("refresh-btn");
const status = document.getElementById("status");

// On launch: install/update the bridge script inside Resolve's Scripts
// folder and tell the user exactly where it landed.
(async () => {
  try {
    status.textContent = await invoke("bridge_status");
  } catch (err) {
    status.textContent = "Startup check failed: " + err;
    status.classList.add("error");
  }
})();

btn.addEventListener("click", async () => {
  btn.disabled = true;
  status.textContent = "Refreshing...";
  status.classList.remove("error");

  try {
    const message = await invoke("refresh_captions");
    status.textContent = message;
  } catch (err) {
    status.textContent = err;
    status.classList.add("error");
  } finally {
    btn.disabled = false;
  }
});
