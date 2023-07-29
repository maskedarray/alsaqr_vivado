# Run post synth simulations

You need to change the Bender.yml to poin to the generated netlist and then, from this folder:

```
vsim -do 'source run_post_sim.sh; quit'
```