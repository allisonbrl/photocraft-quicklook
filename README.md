# PhotoCraft QuickLook & Finder Thumbnail Extension

Extensão nativa de Quick Look e miniaturas para arquivos `.pcraft` do [PhotoCraft](https://github.com/storytold/photocraft) no macOS (Sonoma, Sequoia e superiores).

---

## 📁 Estrutura do Projeto

```text
photocraft-quicklook/
├── README.md
├── docs/
│   ├── ADR-001-macos-quicklook-thumbnail-integration.md   # Registro formal de decisão
│   └── GITHUB_ISSUE_TEMPLATE.md                          # Proposta pronta para o repo oficial
├── src/
│   ├── HostMain.swift          # App host silencioso (LSUIElement)
│   ├── ExtensionMain.m         # QLPreviewProvider (Barra de espaço / QuickLook)
│   └── ThumbnailMain.m         # QLThumbnailProvider (Miniaturas e coluna do Finder)
└── scripts/
    └── build.sh                # Script de compilação, assinatura e registro
```

---

## 🚀 Como Compilar e Instalar

Para reconstruir o app e reinstalar no macOS:

```bash
cd ~/Projetos/_ferramentas/extensions/photocraft-quicklook
./scripts/build.sh
```

O script automaticamente:
1. Compila o App Host (`/Applications/PCraftQuickLook.app`);
2. Compila as extensões `PCraftPreview.appex` e `PCraftThumbnail.appex`;
3. Aplica os entitlements de Sandbox da Apple;
4. Assina os pacotes com `codesign`;
5. Registra no `LaunchServices` e no `pluginkit`;
6. Reseta o cache do `quicklookd`.

---

## 📝 Documentação e Contribuição Upstream

Consulte:
- [`docs/ADR-001-macos-quicklook-thumbnail-integration.md`](docs/ADR-001-macos-quicklook-thumbnail-integration.md) para a análise técnica detalhada da causa raiz.
- [`docs/GITHUB_ISSUE_TEMPLATE.md`](docs/GITHUB_ISSUE_TEMPLATE.md) para abrir uma issue ou proposta de PR no repositório oficial `storytold/photocraft`.
