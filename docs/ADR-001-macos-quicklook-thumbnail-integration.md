# ADR-001: Suporte a Miniaturas no Finder e Pré-visualização Quick Look para Arquivos .pcraft no macOS

* **Status:** Aceito e Implementado
* **Data:** 2026-11-02
* **Autor:** Allison / Antigravity
* **Contexto:** PhotoCraft (`storytold/photocraft`) e formato `.pcraft`

---

## 1. Contexto do Problema

O aplicativo PhotoCraft salva seus documentos em formato `.pcraft`. Internamente, o `.pcraft` é um arquivo compactado (ZIP formato `Store`/Deflate) contendo:
- `composite/preview.png` (render composto achatado em alta resolução, ex: 765×1024);
- `thumb.png` (miniatura de 191×256 pixels);
- `manifest.json` (árvore de camadas, modos de mesclagem e propriedades);
- `tiles/*.zst` (conteúdo das camadas compactado com zstd).

### O Sintoma
Ao navegar pelo macOS Finder (especialmente em pastas sincronizadas via Microsoft OneDrive / CloudStorage) ou ao pressionar a Barra de Espaço (Quick Look) sobre um arquivo `.pcraft`:
1. O Finder exibia apenas o ícone padrão genérico da aplicação (a raposa azul do PhotoCraft), tornando impossível diferenciar visualmente os arquivos/cenas.
2. O Quick Look nativo falhava ou abortava imediatamente (`SIGABRT 6`), registrando a seguinte exceção no Console:
   ```text
   qlmanage: imageTypeSupportsSubsampling - 'imgType' is nil
   QuickLook: _crashOnNSException(NSException*) -> _QLSimpleCrash -> abort()
   ```

---

## 2. Diagnóstico da Causa Raiz

Foram identificadas duas causas raízes conjuntas:

### Causa 1: Conformance incorreta de UTI no `Info.plist` do PhotoCraft
No arquivo `/Applications/PhotoCraft.app/Contents/Info.plist`, a declaração de tipo exportado define:
```xml
<key>UTExportedTypeDeclarations</key>
<array>
  <dict>
    <key>UTTypeIdentifier</key>
    <string>ai.storyteller.photocraft.document</string>
    <key>UTTypeDescription</key>
    <string>PhotoCraft Document</string>
    <key>UTTypeConformsTo</key>
    <array>
      <string>public.data</string>
      <string>public.image</string>
    </array>
...
```
Ao declarar que conforma com `public.image`, o macOS assume que o arquivo é um fluxo binário de imagem pura diretamente decodificável pelo subsistema ImageIO/CoreGraphics. O sistema despacha a pré-visualização para `/System/Library/QuickLook/Image.qlgenerator`. Quando o `ImageIO` lê a assinatura do cabeçalho ZIP (`PK\x03\x04`), ele falha com `imgType is nil` e aborta com crash do `quicklookd`.

### Causa 2: Incompatibilidade do OneDrive (FileProvider) com Resource Forks
Mecanismos legados de atribuir ícones locais (como `NSWorkspace.shared.setIcon` / atributo estendido `com.apple.FinderInfo` / `kHasCustomIcon`) falham silenciosamente ou são removidos instantaneamente pelo cliente de sincronização do OneDrive, pois pastas em `CloudStorage` utilizam a API moderna `FileProvider` da Apple, que não suporta forks de recursos legados do HFS.

---

## 3. Decisão de Arquitetura

Decidiu-se pela criação de uma solução nativa baseada na arquitetura moderna de **App Extensions** do macOS (macOS 12+ / Sequoia / Sonoma), sem depender de hacks de sistema ou modificações destrutivas no pacote oficial do PhotoCraft.

### Estrutura Adotada: `PCraftQuickLook.app`
Um aplicativo contêiner leve e silencioso (`LSUIElement = true`) hospedando duas extensões XPC especializadas:

1. **`PCraftPreview.appex` (`com.apple.quicklook.preview`)**:
   - Subclasse de `QLPreviewProvider` (`QuickLookUI.framework`);
   - Trata requisições para `ai.storyteller.photocraft.document`;
   - Abre o `.pcraft` como arquivo ZIP sequencial (tempo de leitura < 10ms);
   - Localiza prioritariamente `composite/preview.png` (evitando a miniatura pequena `thumb.png`);
   - Grava em arquivo temporário isolado e retorna via `-[QLPreviewReply initWithFileURL:]`;
   - Permite que o Quick Look nativo forneça suporte completo a zoom, pan, redimensionamento fluido e modo tela cheia.

2. **`PCraftThumbnail.appex` (`com.apple.quicklook.thumbnail`)**:
   - Subclasse de `QLThumbnailProvider` (`QuickLookThumbnailing.framework`);
   - Responde às solicitações dinâmicas de ícones para o Finder;
   - Desenha o render composto dentro do contexto gráfico solicitado pelo sistema operacional (`QLThumbnailReply`).

---

## 4. Consequências e Resultados

* ✅ **Quick Look nativo via Barra de Espaço**: Funciona instantaneamente, renderizando a imagem em resolução total sem engasgos nem travamentos.
* ✅ **Compatível com OneDrive / CloudStorage**: Como as miniaturas e prévias são geradas dinamicamente sob demanda pela extensão do Quick Look, o OneDrive não conflita nem apaga metadados.
* ✅ **Desempenho**: O leitor de ZIP foi escrito em C puro (`open`/`read`/`lseek`), localizando a imagem nos primeiros blocos do arquivo sem necessidade de descompactar o arquivo inteiro nem consumir memória desnecessária.
* ✅ **Portabilidade para o Repositório Oficial**: O código e o design podem ser incorporados diretamente no fluxo de empacotamento do PhotoCraft (`packaging/macos/package.sh`), bastando adicionar o target da extensão ao build do projeto no GitHub.
