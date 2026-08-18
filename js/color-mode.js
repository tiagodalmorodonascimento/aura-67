const colorModeToggle=document.querySelector('#colorModeToggle');
function applyColorMode(mode){const dark=mode==='dark';document.documentElement.dataset.colorMode=dark?'dark':'light';localStorage.setItem('aura67_color_mode',dark?'dark':'light');colorModeToggle.setAttribute('aria-pressed',String(dark));colorModeToggle.setAttribute('aria-label',dark?'Ativar modo claro':'Ativar modo escuro');colorModeToggle.title=dark?'Mudar para tema claro':'Mudar para tema escuro';document.querySelector('meta[name="theme-color"]')?.setAttribute('content',dark?'#11141b':'#f4f2f7')}
applyColorMode(document.documentElement.dataset.colorMode==='dark'?'dark':'light');
colorModeToggle.addEventListener('click',()=>applyColorMode(document.documentElement.dataset.colorMode==='dark'?'light':'dark'));
