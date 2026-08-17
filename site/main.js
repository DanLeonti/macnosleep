document.getElementById("year").textContent = String(new Date().getFullYear());

// Non-Mac visitors get told before they download a .app they cannot run.
if (!/Mac/i.test(navigator.platform || navigator.userAgent)) {
  document.querySelectorAll('a[href$=".dmg"]').forEach((link) => {
    link.addEventListener("click", (event) => {
      const proceed = window.confirm(
        "MacNoSleep only runs on macOS 14 or later. Download anyway?"
      );
      if (!proceed) event.preventDefault();
    });
  });
}
