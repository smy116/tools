(() => {
  const shellQuote = (value) => "'" + value.replace(/'/g, "'\\''") + "'";
  const fallbackToken = (id) => "<" + id.replace(/[A-Z]/g, (letter) => "-" + letter.toLowerCase()) + ">";

  const renderCommand = (card) => {
    const output = card.querySelector("[data-command-output]");
    const button = card.querySelector("[data-copy-command]");
    if (!output || !button) return;

    let command = output.dataset.template || "";
    let complete = true;

    card.querySelectorAll("[data-command-input]").forEach((input) => {
      const id = input.dataset.inputId;
      if (!id) return;

      const value = input.value;
      const replacement = value ? shellQuote(value) : fallbackToken(id);
      command = command.replaceAll("{{" + id + "}}", replacement);
      if (!value) complete = false;
    });

    output.textContent = command;
    button.disabled = !complete;
    if (!complete) {
      button.textContent = "填写参数";
    } else if (button.dataset.copied !== "true") {
      button.textContent = "复制";
    }
  };

  const copyText = async (text) => {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(text);
      return;
    }

    const textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.setAttribute("readonly", "");
    textarea.style.position = "fixed";
    textarea.style.opacity = "0";
    document.body.appendChild(textarea);
    textarea.select();
    document.execCommand("copy");
    textarea.remove();
  };

  document.querySelectorAll("[data-command-card]").forEach((card) => {
    renderCommand(card);

    card.querySelectorAll("[data-command-input]").forEach((input) => {
      input.addEventListener("input", () => renderCommand(card));
    });

    const button = card.querySelector("[data-copy-command]");
    const output = card.querySelector("[data-command-output]");
    button?.addEventListener("click", async () => {
      if (!output || button.disabled) return;
      await copyText(output.textContent || "");
      button.dataset.copied = "true";
      button.textContent = "已复制";
      window.setTimeout(() => {
        button.dataset.copied = "false";
        renderCommand(card);
      }, 1400);
    });
  });

  const search = document.querySelector("[data-tool-search]");
  const filters = Array.from(document.querySelectorAll("[data-platform-filter]"));
  const cards = Array.from(document.querySelectorAll("[data-tool-card]"));
  const count = document.querySelector("[data-tool-count]");
  let activePlatform = "all";

  const updateToolList = () => {
    const query = (search?.value || "").trim().toLowerCase();
    let visibleCount = 0;

    cards.forEach((card) => {
      const haystack = (card.dataset.search || "").toLowerCase();
      const platforms = (card.dataset.platforms || "").split(",");
      const matchesQuery = !query || haystack.includes(query);
      const matchesPlatform = activePlatform === "all" || platforms.includes(activePlatform);
      const visible = matchesQuery && matchesPlatform;
      card.hidden = !visible;
      if (visible) visibleCount += 1;
    });

    if (count) {
      count.textContent = String(visibleCount);
    }
  };

  search?.addEventListener("input", updateToolList);
  filters.forEach((filter) => {
    filter.addEventListener("click", () => {
      activePlatform = filter.dataset.platformFilter || "all";
      filters.forEach((button) => {
        button.setAttribute("aria-pressed", String(button === filter));
      });
      updateToolList();
    });
  });

  updateToolList();
})();
