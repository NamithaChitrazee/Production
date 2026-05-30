## 🧪 Bash Script Documentation: Introducing New Physics `Stage5_signal.sh`

### **1. Overview**

The `Stage5_signal.sh` script is designed for **signal injection** to create multiple mixed (signal + background) "pseudo-experiment" datasets. This allows physicists to test analysis techniques under specific signal hypotheses without running full-scale, expensive simulations for every $R_{\mu e}$ rate.

| Component | Description |
| :--- | :--- |
| **Purpose** | To combine a pre-existing background ensemble (the `KNOWN` sample) with a statistically relevant amount of the signal (`SIGNAL`) at a chosen conversion rate (`RATE`). This mixing is done for `NEXP` independent trials. |
| **Prerequisites** | Requires a configuration file (`.txt`) from a previous stage. Requires `calculateEvents.py`, `mu2e` job tools, and SAM tools (`samDatasetsSummary.sh`, `mu2eDatasetFileList`). |
| **Outcome** | `NEXP` sets of output files (`nts` Ntuples and mixed file lists) where background events are randomly mixed with a Poisson-sampled quantity of signal events, prepared for Stage 6 (blind and mix) processing. |

### **2. Usage**

The script requires a known background tag, signal dataset name, known physics dataset names, signal dataset name, and a conversion rate.

```bash
Stage5_signal.sh --known <MDS_TAG> --signal <SIGNAL_NAME> --rate <RATE> \
  --mdsfiles <NTUPLE_DATASET> --mdsmcs <MCS_DATASET> --signalmcs <SIGNAL_MCS_DATASET> [OPTIONS]
```

### **3. Arguments & Default Parameters**

The following parameters control the mixing process and define the input datasets.

| Argument | Variable | Default | Description |
| :--- | :--- | :--- | :--- |
| `--known` | `KNOWN` | `MDS3a` | Tag of the background ensemble (required, cannot be default). |
| `--signal` | `SIGNAL` | `CeMLeadingLogMix1BBTriggered` | Name of the signal sample (required, cannot be default). |
| `--rate` | `RATE` | $1 \times 10^{-13}$ | The hypothesized $\mathbf{R}_{\mu \mathbf{e}}$ conversion rate to use for sampling the signal yield. |
| `--mdsfiles` | `MDSFILES` | (required) | Full ntuple dataset name for known physics (e.g., `nts.mu2e.ensemble...root`). |
| `--mdsmcs` | `MDSMCS` | (required) | Full mcs dataset name for known physics (e.g., `mcs.mu2e.ensemble_RELEASE_PURPOSE_VERSION.art`). |
| `--signalmcs` | `SIGNALMCS` | (required) | Full mcs dataset name for signal (e.g., `mcs.mu2e.SIGNAL_RELEASE_PURPOSE_VERSION.art`). |
| `--nexp` | `NEXP` | $1$ | **Number of Pseudo-Experiments:** How many random mixed samples to create. |
| `--chooselivetime` | `CHOOSE` | $0$ | Optional: Manually set a smaller live time (in seconds) to subsample the background ensemble. |
| `--owner` | `OWNER` | `mu2e` | The dataset owner. |
| `--release` | `RELEASE` | (extracted) | *Automatically extracted from `--signalmcs` dataset name.* |
| `--dbpurpose` | `DBPURPOSE` | (extracted) | *Automatically extracted from `--signalmcs` dataset name.* |
| `--dbversion` | `DBVERSION` | (extracted) | *Automatically extracted from `--signalmcs` dataset name.* |

---

### **4. Execution Flow**

The script's core function is to calculate the precise number of signal and background files needed to match the requested live time and $R_{\mu e}$ rate for $N$ pseudo-experiments.

#### **Phase A: Parse Dataset Names & Extract Version Parameters**

1.  **Extract Version Information:** The script parses the `--signalmcs` dataset name to automatically extract `RELEASE`, `DBPURPOSE`, and `DBVERSION`. 
    * Dataset format: `mcs.mu2e.<NAME>.<RELEASE>_<PURPOSE>_<VERSION>.art`
    * Example: `mcs.mu2e.CeMLeadingLogMix1BBTriggered.MDC2025an_best_v1_3.art` extracts:
      - `RELEASE = MDC2025an`
      - `DBPURPOSE = best`
      - `DBVERSION = v1_3`
    * This ensures consistency between the requested datasets and the output file naming.

2.  **Quote Stripping:** All values read from configuration files have quotes stripped to handle shell variable quoting properly.

#### **Phase B: Load Configuration & Determine Live Time**

1.  **Retrieve Config:** The script reads the configuration file (`${KNOWN}.txt`) to extract the original `GEN_LIVETIME` and `BB` (Beam Batch) mode.

2.  **Live Time Adjustment:**
    * If `--chooselivetime` (`CHOOSE`) is set, the script overrides the original `LIVETIME`.
    * It calculates the number of background files (`N_KNOWN_FILES_TO_USE`) required to achieve this live time, based on the `LIVETIME_PER_FILE`.
    * The `LIVETIME` is then fixed to the total live time contained in this integer number of background files.

3.  **Log Combined Sample Info:** Appends the final chosen `RATE`, `LIVETIME`, and `NEXP` to the configuration file.

#### **Phase C: Loop for Pseudo-Experiments**

The main logic runs in a `while [ $i -le ${NEXP} ]` loop, creating one mixed sample per iteration.

1.  **Calculate Signal Yield ($\mathbf{N}_{\mathbf{SIG}}$):**
    ```bash
    NSIG=$(calculateEvents.py --livetime ${LIVETIME} --prc ${SIGNAL} --BB ${BB} --rue ${RATE})
    ```
    The script uses `calculateEvents.py` to determine the mean expected number of signal events (`NSIG`) for the chosen $R_{\mu e}$ rate and the determined `LIVETIME`.

2.  **Calculate Required Signal Files:**
    The required number of signal events (`NSIG`) is converted into the number of signal files (`N_SIGNAL_FILES_TO_USE`) needed, based on the total generated events and total files in the raw signal MC sample.

3.  **Signal Splitting and Sampling:**
    * **Random File Selection:** `shuf -n ${N_SIGNAL_FILES_TO_USE}` randomly selects the required number of files from the master signal file list.
    * **FCL Generation (`splitter_$i.fcl`):** A temporary FCL configuration is built pointing to the randomly selected files.
    * **Event Splitting:** The `mu2e` application runs with a special split module, creating a new `.art` file containing exactly `NSIG` signal events.
    
4.  **Ntuple Production:**
    ```bash
    mu2e -c ntuple_$i.fcl mcs.<split_file>.art
    ```
    The split signal `.art` file is processed to create a final analysis Ntuple (`.root`). The **full absolute path** to this ntuple is stored for use in Stage 6.

5.  **Background Mixing List:**
    ```bash
    shuf -n ${N_KNOWN_FILES_TO_USE} filenames_All_${KNOWN} >> temp
    shuf temp > filenames_ChosenMixed_$i
    ```
    The required number of background Ntuples are randomly selected from the master background list and combined with the newly created signal Ntuple (stored with absolute path), forming the final list for the $i$-th pseudo-experiment.
    
    
## 🔗 Combining Ntuples `Stage6_blind_and_mix.sh`

### **1. Overview**

This utility script runs after `Stage5_signal.sh`. It takes the list of randomly chosen individual background Ntuples and the newly generated signal Ntuple for a single pseudo-experiment (PE) and merges them into a smaller, more manageable set for final analysis.

| Component | Description |
| :--- | :--- |
| **Purpose** | To perform a sequential merge of analysis Ntuples (`.root` files) from a single pseudo-experiment using the ROOT utility `hadd`, creating a condensed final dataset for analysis. |
| **Input** | A list of Ntuple files (`filenames_ChosenMixed_$i`) generated in Stage 5, and the configuration file (`${KNOWN}.txt`). |
| **Tool Used** | `hadd` (ROOT Histo Adder) – a utility specifically designed for merging ROOT files while preserving their data structures. Uses the `-k` flag to skip over inconsistent or missing branches when merging signal and background samples.  |
| **Outcome** | A single output directory (`merged_files_$i`) containing one or more merged Ntuple files, plus a list file (`merged_list_$i.txt`) tracking the merged files. |

### **2. Usage**

The script takes two positional arguments: the iteration number (`i`) of the pseudo-experiment and the known background tag (`KNOWN`).

```
Stage6_blind_and_mix.sh <pseudo_experiment_iteration> <known_background_tag>
```

### **3. Parameter Extraction**

The script first reads key parameters from the Stage 5 configuration file (`${KNOWN}.txt`) to correctly name the output merged files:

| Variable | Source from Config | Description |
| :--- | :--- | :--- |
| `LIVETIME` | `livetime_combined` | The final effective live time of the merged sample. |
| `RMUE` | `Rmue` | The $R_{\mu e}$ conversion rate used to inject the signal. |
| `SIGNAL` | `signal` | The name of the injected signal. |
| `BB` | `BB` | The Beam Batch mode (`1BB` or `2BB`). |

All values have quotes stripped to handle shell variable quoting properly.

The full output file name is constructed using all these parameters:
$$
\text{OUTNAME} = \text{nts.mu2e.ensemble}\mathbf{KNOWN}\text{Mix}\mathbf{BB}\_\mathbf{SIGNAL}\_\mathbf{RMUE}\_\mathbf{LIVETIME}.\mathbf{i}
$$

### **4. Merge Execution**

The core logic uses the **ROOT `hadd` utility** to merge files in batches for efficiency. 

1.  **Input File List:** The script reads the list of Ntuples to be merged from the file `filenames_ChosenMixed_$i` (created in Stage 5). Both relative and absolute paths are handled, with quotes automatically stripped from filenames.

2.  **Batch Processing:**
    * The variable `FILES_PER_MERGE` (set to `2` in the script) defines how many individual Ntuples are grouped for each `hadd` call.
    * The script iterates through the input list, accumulating files into the `file_group` array.

3.  **Hadd Command:** When the `file_group` array reaches `FILES_PER_MERGE`, the merge is executed:
    ```bash
    hadd -f -k "$output_filename" "${file_group[@]}"
    ```
    * `-f`: Forces overwriting of the output file if it exists.
    * `-k`: Skips over missing or inconsistent branches (allows merging signal and background with different branch structures).
    * `"${file_group[@]}"`: The list of input Ntuples to merge.

4.  **Output Tracking:**
    * Merged files are placed into a dedicated directory: `merged_files_$i`.
    * The name of each resulting merged file is written to `merged_list_$i.txt`.

5.  **Final Group Merge:** The script ensures that any remaining files in the last, incomplete batch are also merged and accounted for.
