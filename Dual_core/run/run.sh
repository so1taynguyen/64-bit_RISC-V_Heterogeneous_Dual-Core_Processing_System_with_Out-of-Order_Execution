if [ ! -d "./my_work_dir" ]; then
    mkdir ./my_work_dir
fi

python3 ../include/RV64IMD_assembler.py

xrun -work WORK -access +r -sv ../test/dual_testbench.sv -l ./my_work_dir/xrun.log -xmlibdirpath ./my_work_dir +define+DEBUG_EN > /dev/null

if grep -q "xmvlog: .*W" ./my_work_dir/xrun.log; then
    echo "WARNING detected:"
    grep "xmvlog: .*W" ./my_work_dir/xrun.log
fi

if grep -q "xmelab: \*W" ./my_work_dir/xrun.log; then
    echo "WARNING detected:"
    grep "xmelab: \*W" ./my_work_dir/xrun.log
fi

if grep -q "xmvlog: .*E" ./my_work_dir/xrun.log; then
    echo "ERROR detected:"
    grep "xmvlog: .*E" ./my_work_dir/xrun.log
fi

if grep -q "xmsim: \*E" ./my_work_dir/xrun.log; then
    echo "ERROR detected:"
    grep "xmsim: \*E" ./my_work_dir/xrun.log
fi

if grep -q "TB ERROR" ./my_work_dir/dual_testbench.log; then
    echo "ERROR detected:"
    grep "TB ERROR" ./my_work_dir/dual_testbench.log
fi

mv dump.vcd ./my_work_dir