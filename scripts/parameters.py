import pathlib, subprocess, tempfile
root=pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    for parameter,value in [('DEPTH',3),('DEPTH',6),('WIDTH',0)]:
        binary=str(pathlib.Path(tmp)/'test')
        compile=subprocess.run(['iverilog','-g2012','-s','async_fifo',f'-Pasync_fifo.{parameter}={value}','-o',binary,str(root/'rtl/async_fifo.sv')],capture_output=True,text=True)
        if compile.returncode:
            raise AssertionError(compile.stderr)
        run=subprocess.run(['vvp',binary],capture_output=True,text=True)
        assert run.returncode!=0 and 'async_fifo:' in run.stdout
        print(f'PASS rejected {parameter}={value}: '+run.stdout.splitlines()[0])
