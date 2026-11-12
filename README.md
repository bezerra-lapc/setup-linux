# setup-linux

[![Shell](https://img.shields.io/badge/Shell-Bash-89e051)]()
[![Linux](https://img.shields.io/badge/Linux-Ubuntu-E95420)]()
[![License](https://img.shields.io/badge/License-MIT-green)]()

Script para configuração automatizada de ambiente de desenvolvimento no **Ubuntu**.

## Compatibilidade

- **Ubuntu** (qualquer versão — o script verifica `ID=ubuntu` em `/etc/os-release`)
- Outras distribuições (**Linux Mint, Debian, Fedora** etc.) são recusadas com uma mensagem explicando o motivo

O script usa `apt`/`dpkg` e lê o codename do Ubuntu de `/etc/os-release` (com fallback para `lsb_release -cs`), para que os repositórios de terceiros apontem para a sua versão.

## Política de versões

Sempre que o programa tem uma linha **LTS**, é ela que é instalada:

| Programa | Versão instalada |
| --- | --- |
| Node.js + npm | **LTS ativa mais recente** via NodeSource (`setup_lts.x`) — o major é detectado na hora, sem número fixo no script |
| Docker | canal `stable` do repositório oficial (o Docker não tem LTS); se o repositório oficial ainda não suportar sua versão do Ubuntu, usa `docker.io` + `docker-compose-v2` do próprio Ubuntu |
| Git, gh, Zsh, Neovim, autojump, Diodon | versão estável dos repositórios do Ubuntu |
| Oh My Zsh e plugins do Zsh | versão atual dos repositórios oficiais no GitHub |

---

## Instalações realizadas

### Dependências base

- **ca-certificates**, **curl**, **gnupg**, **software-properties-common**
- Habilita o repositório `universe` (necessário para `gh`, `autojump` e `diodon`)

### Git + identidade

- **git** — controle de versão
- Em terminal interativo, pergunta `user.name` e `user.email` globais (Enter mantém o valor atual)

### GitHub CLI (gh)

- **gh** — autentique depois com `gh auth login`

### Docker

- `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin`
- Habilita e inicia o serviço e adiciona o usuário ao grupo `docker` (requer logout/login)

### Node.js LTS (NodeSource)

- `node` (LTS ativa) e `npm` (incluído)
- Remove o pacote `npm` do Ubuntu, se existir, pois ele conflita com o do NodeSource
- Em reexecuções, atualiza o Node quando sai uma nova LTS

### Zsh + Oh My Zsh (shell principal)

- **zsh** via `apt` e **Oh My Zsh** em `~/.oh-my-zsh` (`--unattended --keep-zshrc`)
- Plugins: `git`, `zsh-autosuggestions`, `zsh-completions`, `history-substring-search`, `autojump`, `zsh-syntax-highlighting`
- Define o `zsh` como shell de login (`chsh`)

> ⚠️ A linha `plugins=(...)` do `~/.zshrc` é substituída inteira pela lista acima.

### Neovim

- **neovim** (`nvim`)

### Diodon

Gerenciador de área de transferência (clipboard manager):

- `diodon` — interface GTK + indicador de painel

---

## Validação item a item

Cada programa registra a própria validação e, ao final, o script confere tudo:

```text
✅ curl                           INSTALADO
✅ Git                            INSTALADO
✅ GitHub CLI (gh)                INSTALADO
✅ Docker Engine + Compose        INSTALADO
✅ Node.js 26 LTS                 INSTALADO
✅ npm                            INSTALADO
✅ Zsh                            INSTALADO
✅ Oh My Zsh                      INSTALADO
✅ Plugins do Zsh                 INSTALADO
✅ Zsh como shell padrão          INSTALADO
✅ Neovim (nvim)                  INSTALADO
✅ Diodon (clipboard)             INSTALADO
```

- **Todos OK**: termina com código `0`
- **Falta algum item**: aparece como `NÃO INSTALADO` e o script termina com código `1`

| Item | Critério |
| --- | --- |
| curl / Git / gh / Zsh / Neovim | comando disponível no `PATH` |
| Docker | `docker` + `docker compose version` |
| Node.js LTS | major igual ao da LTS atual e `process.release.lts` definido |
| npm | comando `npm` disponível |
| Oh My Zsh | `~/.oh-my-zsh/oh-my-zsh.sh` existe |
| Plugins do Zsh | plugins clonados, `autojump` instalado e todos ativos no `~/.zshrc` |
| Shell padrão | shell de login em `/etc/passwd` aponta para o `zsh` |
| Diodon | pacote `diodon` instalado (`dpkg`) e comando disponível |

---

## Execução

```bash
git clone https://github.com/bezerra-lapc/setup-linux.git
cd setup-linux
chmod +x setup-linux.sh
./setup-linux.sh
```

> **Nota:** execute como usuário comum (não root); o script usa `sudo` internamente.
> Pode ser reexecutado com segurança: o que já está instalado é mantido.

---

## Pós-instalação

1. **GitHub**: `gh auth login`
2. **Shell**: faça **logout/login** para entrar no **zsh + Oh My Zsh**
3. **Docker**: faça **logout/login** (ou reinicie) para usar Docker sem `sudo`
4. **Diodon**: configure o atalho de teclado (Ubuntu/GNOME):
   - *Configurações > Teclado > Atalhos > Atalhos personalizados*
   - Nome: `Diodon` · Comando: `/usr/bin/diodon` · Atalho: `Super + V`

---

## Estrutura do repositório

```text
setup-linux/
├── LICENSE
├── README.md
└── setup-linux.sh
```

---

## Licença

MIT © [Luiz Bezerra](https://github.com/bezerraluiz)
