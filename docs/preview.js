const form = document.querySelector("#demo");
const preferred = document.querySelector("#preferred");
const draft = document.querySelector("#draft");
const result = document.querySelector("#result");
const original = preferred.defaultValue;

document.querySelector("#preview-button").disabled = false;
form.addEventListener("submit", (event) => {
  event.preventDefault();
  // The demo illustrates the empty-field decision. It has no access to WoW.
  const exampleDefault = preferred.value.trim() ? preferred.value : original;
  result.textContent = draft.value === "" ? exampleDefault : draft.value;
});
