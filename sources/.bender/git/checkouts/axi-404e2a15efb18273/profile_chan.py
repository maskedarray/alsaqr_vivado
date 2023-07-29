import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

def print_channel(df,chans,worst_case,n_slv):
    num_rows = len(chans)
    print(num_rows)
    figure, ax = plt.subplots(num_rows,1)
    i=0
    for chan in data["W/R"].unique():
        if(any(chan in x for x in chans)):
            my_dt = data[data["W/R"]==chan]
            print(my_dt.head())
            del my_dt["t_end"]
            del my_dt["W/R"]
            del my_dt["AX_ID"]
            del my_dt["LEN"]
            del my_dt["UTIL"]
            print(my_dt.head())
            to_plot = my_dt.melt("t_val",var_name="lat_type",value_name="lat")
            sns.scatterplot(ax=ax[i],data=to_plot,x="t_val",y="lat",hue="lat_type", style="lat_type")
            ax[i].set_xlabel('Time [ns]')
            ax[i].set_ylabel('Number of cycles')
            if(chan=="W"):
                ax[i].set_title('Whole write transaction')
                ax[i].axhline(y=worst_case,xmin=0,xmax=to_plot["t_val"].max())
            else:
                ax[i].set_title('Whole read transaction')
                ax[i].axhline(y=n_slv*worst_case,xmin=0,xmax=to_plot["t_val"].max())
            print(to_plot["t_val"].max())
            i = i+1
    plt.show()
                  
data = pd.read_csv("traces_ID_0.dat", delimiter=',', sep='\n')
data['TOT'] = data['ACC'] + data['CHAN']
print(data.head())
print(data["W/R"].unique())
w_chan = ["W","R"]
n_mast = 2
n_slv = 2
n_out = 8
B = 8 + 1
worst_case = n_mast * n_out * B
print_channel(data,w_chan,worst_case,n_slv)

