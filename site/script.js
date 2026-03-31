const videos = document.querySelectorAll("video");

videos.forEach((video) => {
  const source = video.querySelector("source");
  if (!source || !source.getAttribute("src")) {
    video.removeAttribute("controls");
  }
});

const kitPanels = document.querySelectorAll("[data-kit]");
const previewButton = document.getElementById("kit-preview-button");
const previewLabel = document.getElementById("kit-preview-label");
const previewStatus = document.getElementById("kit-preview-status");

const kitSamples = {
  electronic: [
    "./audio/electronic/housekick.wav",
    "./audio/electronic/houseclap.wav",
    "./audio/electronic/househihat.wav"
  ],
  acoustic: [
    "./audio/acoustic/acoustickick.wav",
    "./audio/acoustic/acousticsnare.wav",
    "./audio/acoustic/acoustichihat.wav"
  ]
};

let selectedKit = "electronic";
let previewTimeouts = [];

function setSelectedKit(kitId) {
  selectedKit = kitId;

  kitPanels.forEach((panel) => {
    const isActive = panel.dataset.kit === kitId;
    panel.classList.toggle("is-active", isActive);
    panel.setAttribute("aria-pressed", String(isActive));
  });

  const label = kitId === "acoustic" ? "Acoustic" : "Electronic";
  previewLabel.textContent = `Play ${label} Kit`;
  previewStatus.textContent = `Selected: ${label}`;
}

function stopPreviewSequence() {
  previewTimeouts.forEach((timeout) => window.clearTimeout(timeout));
  previewTimeouts = [];
}

function playSample(url) {
  const audio = new Audio(url);
  audio.currentTime = 0;
  audio.play().catch(() => {
    previewStatus.textContent = "Tap play again to allow audio preview.";
  });
}

function playKitPreview() {
  stopPreviewSequence();

  const samples = kitSamples[selectedKit];
  if (!samples) return;

  const label = selectedKit === "acoustic" ? "Acoustic" : "Electronic";
  previewStatus.textContent = `Playing ${label} preview...`;

  samples.forEach((sample, index) => {
    const timeout = window.setTimeout(() => {
      playSample(sample);
      if (index === samples.length - 1) {
        window.setTimeout(() => {
          previewStatus.textContent = `Selected: ${label}`;
        }, 280);
      }
    }, index * 240);

    previewTimeouts.push(timeout);
  });
}

kitPanels.forEach((panel) => {
  panel.addEventListener("click", () => setSelectedKit(panel.dataset.kit));
});

if (previewButton) {
  previewButton.addEventListener("click", playKitPreview);
}

setSelectedKit(selectedKit);
