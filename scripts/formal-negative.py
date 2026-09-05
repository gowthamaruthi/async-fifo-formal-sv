"""Run an isolated formal data-corruption mutation; require a counterexample."""
import os, pathlib, shutil, subprocess, tempfile
root = pathlib.Path(__file__).resolve().parents[1]
python = pathlib.Path(os.environ.get('SBY_PYTHON', root/'build/venv/bin/python')).absolute()
sby = pathlib.Path(os.environ.get('SBY_SOURCE', root/'build/sby/sbysrc/sby.py')).resolve()
with tempfile.TemporaryDirectory() as tmp:
    p=pathlib.Path(tmp)
    for directory in ['rtl','formal']:
        (p/directory).mkdir()
    for name in ['rtl/async_fifo.sv','formal/properties.svh','formal/harness.sv','formal/fifo.sby']:
        shutil.copy(root/name,p/name)
    dut=p/'rtl/async_fifo.sv'
    dut.write_text(dut.read_text().replace('assign rd_data = mem[rd_bin[ADDR_W-1:0]];', 'assign rd_data = ~mem[rd_bin[ADDR_W-1:0]];'))
    config=p/'formal/fifo.sby'
    config.write_text(config.read_text().replace('bmc: depth 22','bmc: depth 12'))
    result=subprocess.run([str(python),str(sby),'-f','formal/fifo.sby','bmc'],cwd=p,capture_output=True,text=True)
    print(result.stdout)
    status=(p/'formal/fifo_bmc/status').read_text().split()[0]
    assert result.returncode != 0 and status=='FAIL', 'formal mutation escaped or tool failed'
    print('PASS: formal data corruption produced a counterexample')
