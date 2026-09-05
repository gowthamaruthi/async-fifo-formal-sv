"""Temporary data/reset mutations must produce simulator failures."""
import pathlib, subprocess, tempfile
root = pathlib.Path(__file__).resolve().parents[1]
source = (root/'rtl/async_fifo.sv').read_text()
mutations = [
 ('assign rd_data = mem[rd_bin[ADDR_W-1:0]];', 'assign rd_data = ~mem[rd_bin[ADDR_W-1:0]];', 'order/data mismatch'),
 ('if (wr_rst_n && wr_en && !full)', 'if (wr_en && !full)', 'memory changed during reset')]
for old,new,message in mutations:
    assert old in source
    with tempfile.TemporaryDirectory() as temp:
        p = pathlib.Path(temp)
        (p/'dut.sv').write_text(source.replace(old,new))
        subprocess.run(['iverilog','-g2012','-s','tb_async_fifo','-o',str(p/'sim'),str(p/'dut.sv'),str(root/'tb/tb_async_fifo.sv')],check=True)
        result = subprocess.run(['vvp',str(p/'sim'),'+SEED=1'],capture_output=True,text=True)
        print(result.stdout)
        assert result.returncode != 0 and message in result.stdout, 'mutation escaped'
        print('PASS: detected',message,'; simulator returned',result.returncode)
