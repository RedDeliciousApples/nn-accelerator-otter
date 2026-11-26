# Simulating

Use Windows PowerShell

## Python environment

Required by `training-tools/`

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install torch torchvision numpy pillow
```

If `Activate.ps1` doesn't work, try  `.\.venv\Scripts\python.exe`

## Run tis first
This just sets some variables and creates a directory for storing your runs.

```powershell
$XV  = 'C:\Xilinx\Vivado\2024.2\bin'
$d   = "$PWD\2022lab8.srcs"
$run = "$PWD\nn-accel.sim"  # scratch folder for runs
New-Item -ItemType Directory -Force $run | Out-Null
$acc = Get-ChildItem "$d\sources_1\new\*.sv" | ForEach-Object { $_.FullName }
```

## nn_accel_tb

Accelerator RTL only.

```powershell
Copy-Item training-tools\artifacts\firmware\otter_data.mem $run -Force
Push-Location $run
& "$XV\xvlog.bat" -sv @acc "$d\sim_1\new\nn_accel_tb.sv"
& "$XV\xelab.bat" -sv nn_accel_tb -s nn_accel_tb_sim
& "$XV\xsim.bat" nn_accel_tb_sim -R
Pop-Location
```

Reads `otter_data.mem` from the run dir.

## otter_nn_tb

To run the full system, which is firmware + CPU + accelerator:

```powershell
python training-tools\export_firmware_data.py 3
python firmware\build.py
Copy-Item firmware\build\otter_memory.mem $run -Force

$cpu = @(
  'ALU','CSR_v1_05','control_unit_dcdr_v_1_07','control_unit_fsm_v_1_07',
  'reg_file_v1_02','dbounce_v1_02','one_shot_posneg_v1_03','otter_memory_v1_06'
) | ForEach-Object { "$d\sources_1\imports\Downloads\$_.sv" }
$cpu += @(
  "$d\sources_1\imports\Downloads\reg_nb_v1_04.v",
  "$d\sources_1\imports\Downloads\mux_8t1_nb_v1_03.v",
  "$d\sources_1\imports\Downloads\mux_4t1_nb_v1_06.v",
  "$d\sources_1\imports\Downloads\mux_2t1_nb_v1_04.v",
  "$d\sources_1\imports\Downloads\lab5\233lab5\233lab5.srcs\sources_1\new\OTTER_MCU.sv",
  "$d\sources_1\imports\Downloads\Exp6_OTTER_Wrapper_v1_02.sv"
)

Push-Location $run
& "$XV\xvlog.bat" -sv @cpu @acc "$d\sim_1\new\otter_nn_tb.sv"
& "$XV\xelab.bat" -sv otter_nn_tb -s otter_nn_tb_sim
& "$XV\xsim.bat" otter_nn_tb_sim -R
Pop-Location
```

If you want to run the software baseline: `python firmware\build.py main_sw.c`.

## GUI

```powershell
Copy-Item firmware\build\otter_memory.mem 2022lab8.sim\sim_1\behav\xsim -Force
```

Then in Vivado set the simulation top (`nn_accel_tb` or `otter_nn_tb`) and Run Simulation.
