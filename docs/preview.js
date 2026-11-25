"use strict";

const form = document.getElementById("demo");
const wallet = document.getElementById("wallet");
const postage = document.getElementById("postage");
const reserve = document.getElementById("reserve");
const result = document.getElementById("result");

function render() {
  if (!form.checkValidity()) {
    result.textContent = "Enter a valid balance and postage.";
    return;
  }
  const copper = Math.round(wallet.valueAsNumber * 10000);
  const surplus = copper - postage.valueAsNumber - reserve.valueAsNumber * 10000;
  if (surplus <= 0) {
    result.textContent = "No transfer. The alt keeps its balance.";
    return;
  }
  const gold = Math.floor(surplus / 10000);
  const silver = Math.floor(surplus / 100) % 100;
  result.textContent = gold + "g " + silver + "s " + (surplus % 100) + "c";
}

form.addEventListener("submit", (event) => {
  event.preventDefault();
  render();
});
form.addEventListener("input", render);

const tourNav = document.querySelector(".tour-nav");
const tourLinks = Array.from(tourNav.querySelectorAll("a"));
const tourPlates = tourLinks.map((link) => document.getElementById(link.hash.slice(1)));

function selectPlate(index) {
  tourLinks.forEach((link, position) => {
    const selected = position === index;
    link.setAttribute("aria-selected", String(selected));
    link.tabIndex = selected ? 0 : -1;
    tourPlates[position].hidden = !selected;
  });
}

function followTourFragment() {
  const index = tourLinks.findIndex((link) => link.hash === location.hash);
  if (index >= 0) selectPlate(index);
}

tourNav.setAttribute("role", "tablist");
const stackedTabs = window.matchMedia("(min-width: 701px)");
function updateTabOrientation() {
  tourNav.setAttribute("aria-orientation", stackedTabs.matches ? "vertical" : "horizontal");
}
updateTabOrientation();
stackedTabs.addEventListener("change", updateTabOrientation);
tourLinks.forEach((link, index) => {
  const plate = tourPlates[index];
  link.setAttribute("role", "tab");
  link.setAttribute("aria-controls", plate.id);
  plate.setAttribute("role", "tabpanel");
  plate.setAttribute("aria-labelledby", link.id);
  plate.tabIndex = 0;
  link.addEventListener("click", (event) => {
    if (event.ctrlKey || event.metaKey || event.altKey || event.shiftKey) return;
    event.preventDefault();
    selectPlate(index);
    history.replaceState(null, "", link.hash);
  });
  link.addEventListener("keydown", (event) => {
    const last = tourLinks.length - 1;
    const directions = {
      ArrowLeft: (index + last) % tourLinks.length,
      ArrowUp: (index + last) % tourLinks.length,
      ArrowRight: (index + 1) % tourLinks.length,
      ArrowDown: (index + 1) % tourLinks.length,
      Home: 0, End: last, " ": index,
    };
    const target = directions[event.key];
    if (target === undefined) return;
    event.preventDefault();
    tourLinks[target].focus();
    tourLinks[target].click();
  });
});
selectPlate(0);
followTourFragment();
window.addEventListener("hashchange", followTourFragment);
