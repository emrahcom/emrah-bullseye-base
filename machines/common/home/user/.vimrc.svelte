
autocmd BufNewFile,BufRead *.svelte call Svelte()
function Svelte()
  setlocal
  \ textwidth=80
  \ tabstop=2
  \ shiftwidth=2
  \ softtabstop=2
  \ expandtab
  \ autoindent
  \ nosmartindent
  \ nocindent
  \ list
  \ listchars=tab:»·,trail:·
  \ filetype=html
  \ syntax=html
endfunction
