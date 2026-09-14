const { invoke } = window.__TAURI__.core;

const btn = document.getElementById("refresh-btn");
const status = document.getElementById("status");

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
