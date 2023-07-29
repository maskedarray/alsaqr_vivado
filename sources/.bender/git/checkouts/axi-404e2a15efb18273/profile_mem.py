import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

def print_channel(df,chans,worst_case,n_slv):
    num_cols = len(chans)
    figure, ax = plt.subplots(3,num_cols)
    i=0
    b =  data['LEN'].iloc[0]+1
    names=["ACC","CHAN","TOT"]
    titles=["ax_valid->ax_ready latency","ax handshake -> last","Total"]
    for chan in data["W/R"].unique():
        if(any(chan in x for x in chans)):
            my_dt = data[data["W/R"]==chan]
            print(my_dt.head())
            for j in range(3):
                sns.scatterplot(ax=ax[j,i],data=my_dt,x="t_0",y=names[j],hue="ID")
                ax[j,i].set_xlabel('Transfer generation t [ns]')
                ax[j,i].set_ylabel('Number of cycles')
                ax[j,i].set_title(chan + " " +  titles[j] + ' transactions time')
            ax[j,i].axhline(y=4*(1+2*(24+(64*b/32))) , c = 'orange') 
            ax[j,i].axhline(y=16*(1+2*(24+(64*b/32))) ) 
            i = i+1
    plt.show()
                  
data = pd.read_csv("traces_rw.dat", delimiter=',', sep='\n')
data['TOT'] = data['ACC'] + data['CHAN']
data['t_0'] = data['t_val'] - data['t_val'].min()
print(data.head())
print(data["W/R"].unique())
w_chan = ["W","R"]
n_mast = 2
n_slv = 2
n_out = 8
B = data['LEN'].iloc[0]+1
worst_case = n_mast * n_out * B
print_channel(data,w_chan,worst_case,n_slv)

