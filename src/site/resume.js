const storageKey = "theme";
const sharedCookieName = "rw-theme";
const sharedCookieDomain = "ryancswallace.dev";
const sharedCookieMaxAge = 60 * 60 * 24 * 365;
const systemTheme = window.matchMedia("(prefers-color-scheme: dark)");

function isTheme(value) {
    return value === "light" || value === "dark";
}

function getSharedTheme() {
    const cookie = document.cookie
        .split(";")
        .map((value) => value.trim())
        .find((value) => value.startsWith(`${sharedCookieName}=`));
    const value = cookie?.slice(sharedCookieName.length + 1);

    return isTheme(value) ? value : null;
}

function getLocalTheme() {
    try {
        const value = localStorage.getItem(storageKey);
        return isTheme(value) ? value : null;
    } catch {
        return null;
    }
}

function setLocalTheme(theme) {
    try {
        localStorage.setItem(storageKey, theme);
    } catch {
        // The shared cookie still preserves the preference when storage is unavailable.
    }
}

function setSharedTheme(theme) {
    document.cookie = `${sharedCookieName}=${theme}; Path=/; Domain=${sharedCookieDomain}; Max-Age=${sharedCookieMaxAge}; SameSite=Lax; Secure`;
}

function getSavedTheme() {
    return getSharedTheme() || getLocalTheme();
}

function saveTheme(theme) {
    setLocalTheme(theme);
    setSharedTheme(theme);
}

function applyTheme(theme, persist = false) {
    document.documentElement.dataset.theme = theme;

    const themeButton = document.querySelector("#theme-btn");
    const nextTheme = theme === "dark" ? "light" : "dark";
    themeButton?.setAttribute("aria-label", `Switch to ${nextTheme} theme`);
    themeButton?.setAttribute("title", `Switch to ${nextTheme} theme`);
    themeButton?.setAttribute("aria-pressed", String(theme === "dark"));

    const background = window.getComputedStyle(document.body).backgroundColor;
    document
        .querySelector('meta[name="theme-color"]')
        ?.setAttribute("content", background);

    if (persist) saveTheme(theme);
}

const sharedTheme = getSharedTheme();
const localTheme = getLocalTheme();

if (sharedTheme) {
    setLocalTheme(sharedTheme);
} else if (localTheme) {
    setSharedTheme(localTheme);
}

applyTheme(document.documentElement.dataset.theme);

document.querySelector("#theme-btn")?.addEventListener("click", () => {
    const nextTheme =
        document.documentElement.dataset.theme === "dark" ? "light" : "dark";
    applyTheme(nextTheme, true);
});

function syncSharedTheme() {
    const sharedPreference = getSharedTheme();

    if (
        sharedPreference &&
        sharedPreference !== document.documentElement.dataset.theme
    ) {
        setLocalTheme(sharedPreference);
        applyTheme(sharedPreference);
    }
}

window.addEventListener("focus", syncSharedTheme);
window.addEventListener("pageshow", syncSharedTheme);

systemTheme.addEventListener("change", (event) => {
    if (!getSavedTheme()) applyTheme(event.matches ? "dark" : "light");
});

const navMenu = document.querySelector("#nav-menu");
const menuButton = document.querySelector("#menu-btn");
const menuItems = document.querySelector("#menu-items");
const menuIcon = document.querySelector("#menu-icon");
const closeIcon = document.querySelector("#close-icon");

function setMenuState(isOpen) {
    if (!menuButton || !menuItems || !menuIcon || !closeIcon) return;

    menuButton.setAttribute("aria-expanded", String(isOpen));
    menuButton.setAttribute("aria-label", isOpen ? "Close menu" : "Open menu");
    menuItems.classList.toggle("is-open", isOpen);
    menuIcon.classList.toggle("hidden", isOpen);
    closeIcon.classList.toggle("hidden", !isOpen);
}

menuButton?.addEventListener("click", () => {
    setMenuState(menuButton.getAttribute("aria-expanded") !== "true");
});

menuItems?.querySelectorAll("a").forEach((link) => {
    link.addEventListener("click", () => setMenuState(false));
});

navMenu?.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") return;

    setMenuState(false);
    menuButton?.focus();
});

document.addEventListener("click", (event) => {
    if (
        menuButton?.getAttribute("aria-expanded") === "true" &&
        event.target instanceof Node &&
        !navMenu?.contains(event.target)
    ) {
        setMenuState(false);
    }
});
