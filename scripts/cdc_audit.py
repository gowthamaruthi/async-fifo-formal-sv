#!/usr/bin/env python3
"""Project-specific Yosys-netlist crossing audit, not a general CDC signoff tool."""
import argparse, json, pathlib, subprocess
ROOT = pathlib.Path(__file__).resolve().parents[1]

def audit(module):
    nets, cells = module['netnames'], module['cells']
    def bits(name): return nets[name]['bits']
    def require(condition, message):
        if not condition: raise ValueError(message)
    drivers, users = {}, {}
    for name, cell in cells.items():
        for port, connections in cell['connections'].items():
            for bit in connections:
                if isinstance(bit, int):
                    if cell['port_directions'][port] == 'output':
                        require(bit not in drivers, f'multiple drivers on bit {bit}')
                        drivers[bit] = name
                    else: users.setdefault(bit, set()).add((name, port))
    def flop(net, clk, rst):
        owners = {drivers.get(b) for b in bits(net)}
        require(len(owners) == 1 and None not in owners, f'{net}: missing/fragmented flop')
        name = next(iter(owners)); c = cells[name]
        require(c['type'] == '$adff', f'{net}: expected asynchronous-reset register')
        require(c['connections']['Q'] == bits(net), f'{net}: unexpected Q mapping')
        require(c['connections']['CLK'] == bits(clk), f'{net}: wrong clock')
        require(c['connections']['ARST'] == bits(rst), f'{net}: wrong reset domain')
        require(int(c['parameters']['CLK_POLARITY'],2)==1, f'{net}: wrong clock polarity')
        require(int(c['parameters']['ARST_POLARITY'],2)==0, f'{net}: reset not active low')
        require(int(c['parameters']['ARST_VALUE'],2)==0, f'{net}: reset not zero')
        return name, c
    chains=[]; approved=set()
    for source, destination in [('wr','rd'),('rd','wr')]:
        signal=source+'_gray'; first=signal+'_q1'; second=signal+'_sync'
        src_name,_=flop(signal,source+'_clk',source+'_rst_n')
        first_name,one=flop(first,destination+'_clk',destination+'_rst_n')
        second_name,two=flop(second,destination+'_clk',destination+'_rst_n')
        require(one['connections']['D']==bits(signal), f'{first}: input must be registered Gray pointer')
        require(two['connections']['D']==bits(first), f'{second}: synchronizer bypass')
        for stage in [first,second]:
            require(nets[stage]['attributes'].get('ASYNC_REG')=='TRUE',f'{stage}: missing ASYNC_REG')
        for bit in bits(first):
            require(users.get(bit)=={(second_name,'D')},f'{first}: stage-one fanout')
        approved.add((src_name,first_name))
        chains.append(dict(source=signal,destination_clock=destination+'_clk',stages=[first,second],width=len(bits(signal))))
    # Trace combinational dependencies from every register D pin back to register Qs.
    # Memories are deliberately separate: their data path needs protocol/ordering verification.
    seq={n:c for n,c in cells.items() if c['type'] in ('$adff','$dff')}
    def roots(bit, seen):
        if bit in seen or bit not in drivers:return set()
        name=drivers[bit]; c=cells[name]
        if name in seq:return {name}
        if c['type'].startswith('$mem'):return set()
        found=set()
        for port,direction in c['port_directions'].items():
            if direction=='input':
                for b in c['connections'][port]:found |= roots(b,seen|{bit})
        return found
    crossings=[]
    for target,c in seq.items():
        origins=set()
        for bit in c['connections']['D']:origins |= roots(bit,set())
        for source in sorted(origins):
            src=seq[source]
            if src['connections']['CLK']!=c['connections']['CLK']:
                require((source,target) in approved,f'unapproved register crossing {source} -> {target}')
                crossings.append([source,target])
            elif src['connections'].get('ARST')!=c['connections'].get('ARST'):
                raise ValueError(f'unapproved same-clock reset-domain crossing {source} -> {target}')
    require(len(crossings)==2,'expected exactly two registered pointer crossings')
    for domain in ['wr','rd']:
        flop(domain+'_bin',domain+'_clk',domain+'_rst_n')
    return dict(status='PASS',chains=chains,registered_crossings=len(crossings),
        reset_contract='Both domains flush together; external synchronous release required.',
        exclusions=['Shared memory data crossing: simulation and bounded formal check ordering.',
                    'External input timing, reset release, metastability, bus skew and physical reconvergence are not checked.'])

def main():
    p=argparse.ArgumentParser();p.add_argument('--rtl',type=pathlib.Path,default=ROOT/'rtl/async_fifo.sv');p.add_argument('--out',type=pathlib.Path,default=ROOT/'build/cdc');p.add_argument('--depth',type=int,default=16);p.add_argument('--width',type=int,default=8);args=p.parse_args()
    args.out.mkdir(parents=True,exist_ok=True)
    # Stage a fixed filename so Yosys does not need to parse caller-supplied path syntax.
    (args.out/'dut.sv').write_text(args.rtl.read_text())
    command=f'read_verilog -sv dut.sv; chparam -set DEPTH {args.depth} -set WIDTH {args.width} async_fifo; hierarchy -top async_fifo; setattr -set keep 1 w:wr_gray_q1 w:wr_gray_sync w:rd_gray_q1 w:rd_gray_sync; proc; opt_clean; write_json netlist.json'
    run=subprocess.run(['yosys','-Q','-T','-p',command],cwd=args.out,capture_output=True,text=True)
    (args.out/'elaborate.log').write_text(run.stdout+run.stderr)
    if run.returncode:raise RuntimeError('Yosys elaboration failed; see elaborate.log')
    result=audit(json.loads((args.out/'netlist.json').read_text())['modules']['async_fifo'])
    result.update(depth=args.depth,width=args.width)
    (args.out/'report.json').write_text(json.dumps(result,indent=2)+'\n')
    print(f'PASS CDC structure DEPTH={args.depth} WIDTH={args.width}: two registered Gray crossings, two stages each; reset connectivity checked')
if __name__=='__main__':main()
