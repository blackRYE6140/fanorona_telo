const APK_BY_ABI = Object.freeze({
  "arm64-v8a": "/apks/app-arm64-v8a-release.apk",
  "armeabi-v7a": "/apks/app-armeabi-v7a-release.apk",
  x86_64: "/apks/app-x86_64-release.apk",
});

const downloadButton = document.getElementById("download-btn");
const statusText = document.getElementById("status");
const manualSection = document.getElementById("manual");

function toLower(value) {
  return typeof value === "string" ? value.toLowerCase() : "";
}

async function collectClientData() {
  const data = {
    ua: navigator.userAgent || "",
    platform: "",
    architecture: "",
    bitness: "",
  };

  if (navigator.userAgentData) {
    data.platform = toLower(navigator.userAgentData.platform || "");

    if (typeof navigator.userAgentData.getHighEntropyValues === "function") {
      try {
        const hints = await navigator.userAgentData.getHighEntropyValues([
          "architecture",
          "bitness",
          "platform",
        ]);
        data.architecture = toLower(hints.architecture || "");
        data.bitness = toLower(hints.bitness || "");
        data.platform = toLower(hints.platform || data.platform);
      } catch (_) {
        // Ignore and continue with basic user agent detection.
      }
    }
  }

  return data;
}

function isAndroid(data) {
  const ua = toLower(data.ua);
  return ua.includes("android") || data.platform.includes("android");
}

function detectAbi(data) {
  const fingerprint = [
    toLower(data.ua),
    toLower(data.architecture),
    toLower(data.bitness),
  ].join(" ");

  if (fingerprint.includes("x86_64") || fingerprint.includes("amd64")) {
    return "x86_64";
  }

  if (
    fingerprint.includes("arm64") ||
    fingerprint.includes("aarch64") ||
    (toLower(data.architecture).includes("arm") && toLower(data.bitness) === "64")
  ) {
    return "arm64-v8a";
  }

  if (
    fingerprint.includes("armeabi-v7a") ||
    fingerprint.includes("armv7") ||
    fingerprint.includes("armv8l") ||
    (toLower(data.architecture).includes("arm") && toLower(data.bitness) === "32")
  ) {
    return "armeabi-v7a";
  }

  return null;
}

function startDownload(path) {
  window.location.assign(path);
}

async function handleDownload() {
  downloadButton.disabled = true;
  statusText.textContent = "Detection du systeme Android en cours...";

  try {
    const clientData = await collectClientData();

    if (!isAndroid(clientData)) {
      statusText.textContent = "Appareil non Android detecte. Utilise le choix manuel ci-dessous.";
      manualSection.hidden = false;
      return;
    }

    const abi = detectAbi(clientData);
    if (!abi || !APK_BY_ABI[abi]) {
      statusText.textContent = "Architecture non detectee avec certitude. Selection manuelle requise.";
      manualSection.hidden = false;
      return;
    }

    statusText.textContent = `Architecture detectee: ${abi}. Telechargement...`;
    startDownload(APK_BY_ABI[abi]);

    // Keep manual links available in case browser blocks automatic navigation.
    setTimeout(function () {
      manualSection.hidden = false;
      downloadButton.disabled = false;
    }, 1500);
    return;
  } catch (_) {
    statusText.textContent = "Erreur de detection. Utilise le choix manuel ci-dessous.";
    manualSection.hidden = false;
    return;
  }

  downloadButton.disabled = false;
}

downloadButton.addEventListener("click", handleDownload);
