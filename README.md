# MCIX DataStage Overlay Apply GitHub Action

Apply one or more **overlay directories** to DataStage export assets using the MCIX `overlay apply` command.

This action lets you take an existing DataStage export (zip or directory), apply a sequence of overlay directories (in order), and write the updated assets to a new zip or directory. Overlays can contain modified JSON, additional assets, or changes driven by a properties file.

> Namespace: `overlay`
> Action: `apply`
> Usage: `DataMigrators/mcix/overlay/apply@v1`

---

## 🧩 What this action does

It wraps the CLI:

```text
Usage: overlay apply [options]
  Options:
  * -assets    Path to DataStage export zip file or directory
  * -output    Zip file or directory to write updated assets
  * -overlay   Directory containing asset overlays. Each overlay will be
               applied in specified order when providing multiple (e.g:
               -overlay dir1 -overlay dir2)
    -properties Properties file with replacement values
````

You provide:

* The **source assets** (zip or directory)
* One or more **overlay directories** (in order)
* An **output** target (zip or directory)
* An optional **properties** file for value substitution

---

## 🚀 Usage

Basic example:

```yaml
jobs:
  apply-overlay:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Apply DataStage overlays with MCIX
        id: mcix-overlay-apply
        uses: DataMigrators/mcix/overlay/apply@v1
        with:
          assets: ./exports/base-assets.zip
          output: ./exports/base-assets-with-overlays.zip
          # You can provide one or more overlay directories:
          overlay: |
            ./overlays/common
            ./overlays/env/dev
          # Optional properties file:
          properties: ./overlays/overlay.properties
```

In this example:

* `base-assets.zip` is your original DataStage export.
* `./overlays/common` is applied first.
* `./overlays/env/dev` is applied second.
* The result is written to `base-assets-with-overlays.zip`.

---

## 🔧 Inputs

| Name         | Required | Description                                                                                                     |
| ------------ | -------- | --------------------------------------------------------------------------------------------------------------- |
| `assets`     | ✅        | Path to the DataStage export zip **or** directory containing the base assets to modify.                         |
| `output`     | ✅        | Path to a zip file **or** directory where the updated assets will be written.                                   |
| `overlay`    | ✅        | One or more overlay directories to apply, **in order**. Provide as a space-separated or newline-separated list. |
| `properties` | ❌        | Optional path to a properties file with replacement values used while applying overlays.                        |

### Multiple overlays

You can pass multiple overlays as either:

```yaml
with:
  overlay: ./overlays/common ./overlays/env/dev
```

or multi-line (easier to read):

```yaml
with:
  overlay: |
    ./overlays/common
    ./overlays/env/dev
```

Your entrypoint script can simply split `PARAM_OVERLAY` on whitespace or newlines and pass each as `-overlay <dir>`.

---

## 📤 Outputs

Match this with your `action.yml` and `entrypoint.sh`:

| Name          | Description                                     |
| ------------- | ----------------------------------------------- |
| `return-code` | Exit code from the `mcix overlay apply` command |

Example:

```yaml
      - name: Check overlay apply result
        run: echo "Overlay apply exit code: ${{ steps.mcix-overlay-apply.outputs.return-code }}"
```

You can also use the `output` path as input to later steps in the workflow (e.g., import or test those updated assets).

---

## 🧪 Example – Overlay then Import

```yaml
jobs:
  overlay-and-import:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Apply overlays to base assets
        id: overlay
        uses: DataMigrators/mcix/overlay/apply@v1
        with:
          assets: ./exports/base-assets.zip
          output: ./exports/overlayed-assets.zip
          overlay: |
            ./overlays/common
            ./overlays/env/test
          properties: ./overlays/test.properties

      - name: Import overlayed assets into DataStage
        id: import
        uses: DataMigrators/mcix/datastage/import@v1
        with:
          api-key: ${{ secrets.MCIX_API_KEY }}
          url: https://your-mcix-server/api
          user: dm-automation
          assets: ./exports/overlayed-assets.zip
          project: GitHub_CP4D_DevOps
```

---

## 📚 More information

See  https://nextgen.mettleci.io/mettleci-cli/overlay-namespace/#overlay-apply

<!-- BEGIN MCIX-ACTION-DOCS -->
# MCIX DataStage Overlay Apply

Apply overlay directories to DataStage export assets using the MCIX overlay apply command.

> Namespace: `overlay`<br>
> Action: `apply`<br>
> Usage: `${{ github.repository }}/overlay/apply@v1`

... where `v1` is the version of the action you wish to use.

---

## 🚀 Usage

Minimal example:

```yaml
jobs:
  overlay-apply:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

      - name: Run MCIX DataStage Overlay Apply
        id: overlay-apply
        uses: ${{ github.repository }}/overlay/apply@v1
        with:
          assets: <required>
          output: <required>
          overlays: <required>
          # properties: <optional>
```

---

## 🔧 Inputs

| Name | Required | Default | Description |
| --- | --- | --- | --- |
| `assets` | ✅ |  | Path to DataStage export zip file or directory. |
| `output` | ✅ |  | Zip file or directory to write updated assets. |
| `overlays` | ✅ |  | One or more overlay directories. Overlays are applied in the order specified.
Provide as comma- or newline-separated list.
Example:
  overlays: overlays/base, overlays/customer
  or
  overlays: \|
    overlays/base
    overlays/customer |
| `properties` | ❌ |  | Optional properties file with replacement values. |

---

## 📤 Outputs

| Name | Description |
| --- | --- |
| `return-code` | Exit code returned by the mcix overlay apply command. |

---

## 🧱 Implementation details

- `runs.using`: `docker`
- `runs.image`: `Dockerfile`

---

## 🧩 Notes

- The sections above are auto-generated from `action.yml`.
- To edit this documentation, update `action.yml` (name/description/inputs/outputs).
<!-- END MCIX-ACTION-DOCS -->
