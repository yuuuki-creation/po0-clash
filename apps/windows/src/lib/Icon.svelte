<script>
  let { name, class: extra = '' } = $props();

  const paths = {
    home: ['M4 4h7v7H4zM13 4h7v4h-7zM13 10h7v10h-7zM4 13h7v7H4z'],
    proxies: ['M12 3a9 9 0 1 0 0 18a9 9 0 0 0 0-18ZM3 12h18M12 3c3 3 3.5 6 3.5 9s-.5 6-3.5 9c-3-3-3.5-6-3.5-9s.5-6 3.5-9Z'],
    profiles: ['M12 3 3 8l9 5 9-5-9-5ZM3 13l9 5 9-5M3 18l9 5 9-5'],
    whitelist: ['M12 3l8 3v6c0 4.5-3.2 7.6-8 9-4.8-1.4-8-4.5-8-9V6l8-3ZM8.5 12l2.5 2.5 4.5-5'],
    activity: ['M3 12h4l3-8 4 16 3-8h4'],
    tools: ['M4 7h9M17 7h3M4 17h3M11 17h9M13 5h4v4h-4zM7 15h4v4H7z'],
    pane: ['M4 6h16M4 12h16M4 18h16'],
    refresh: ['M20 11a8 8 0 1 0-2.3 6M20 5v6h-6'],
    moreH: ['M5 12h.01M12 12h.01M19 12h.01'],
    min: ['M5 12h14'],
    max: ['M6 6h12v12H6z'],
    restore: ['M6 9h9v9H6Z', 'M9 6h9v9'],
    close: ['M6 6l12 12M18 6 6 18'],
    down: ['M12 5v14M7 14l5 5 5-5'],
    up: ['M12 19V5M7 10l5-5 5 5'],
    search: ['M11 4a7 7 0 1 0 0 14a7 7 0 0 0 0-14ZM20 20l-4-4'],
    trash: ['M4 7h16M9 7V4h6v3M6.5 7l1 13h9l1-13'],
    chevron: ['M9 5l7 7-7 7'],
    chevDown: ['M6 9l6 6 6-6'],
    check: ['M5 12.5l4.5 4.5L19 7.5'],
    plus: ['M12 5v14M5 12h14'],
    bolt: ['M13 3 5 14h6l-1 7 8-11h-6l1-7Z'],
    locate: ['M12 8a4 4 0 1 0 0 8a4 4 0 0 0 0-8ZM12 3v3M12 18v3M3 12h3M18 12h3'],
    grip: ['M9 6h.01M15 6h.01M9 12h.01M15 12h.01M9 18h.01M15 18h.01'],
    edit: ['M4 20h4L19 9l-4-4L4 16Z', 'M13 7l4 4'],
    warning: ['M12 4L2.8 20h18.4Z', 'M12 10v4.5', 'M12 17.5h.01'],
    doc: ['M6 3h8l4 4v14H6Z', 'M14 3v4h4', 'M9 12h6', 'M9 16h6'],
    branch: ['M6 15.5a2.5 2.5 0 1 0 0 5a2.5 2.5 0 1 0 0-5Z', 'M18 3.5a2.5 2.5 0 1 0 0 5a2.5 2.5 0 1 0 0-5Z', 'M6 3v12.5', 'M18 8.5a9.5 9.5 0 0 1-9.5 9.5'],
    link: ['M10 13a5 5 0 0 0 7.5.5l3-3a5 5 0 0 0-7-7l-1.7 1.7', 'M14 11a5 5 0 0 0-7.5-.5l-3 3a5 5 0 0 0 7 7l1.7-1.7'],
    rules: ['M8 6h12', 'M8 12h12', 'M8 18h12', 'M4 6h.01', 'M4 12h.01', 'M4 18h.01'],
    providers: ['M4 6h16', 'M4 12h16', 'M4 18h10', 'M18 16v4', 'M16 18h4'],
    loop: ['M17 4l3 3l-3 3', 'M20 7H8a4 4 0 0 0-4 4', 'M7 20l-3-3l3-3', 'M4 17h12a4 4 0 0 0 4-4'],
  };
</script>

<svg class="ic {extra}" class:dots={name === 'moreH' || name === 'grip'} viewBox="0 0 24 24" aria-hidden="true">
  {#each paths[name] as d (d)}
    <path {d} />
  {/each}
</svg>
