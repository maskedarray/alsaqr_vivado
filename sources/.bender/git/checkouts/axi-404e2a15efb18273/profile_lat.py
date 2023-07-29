import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

def print_channel(df,chans):
    num_rows = len(chans)
    figure, axis = plt.subplots(num_rows,1)
    i=0
    for chan in data["Channel"].unique():
        if(any(chan in x for x in chans)):
            my_dt = data[data["Channel"]==chan]
            del my_dt["Channel"]
            del my_dt["t_handshake"]
            to_plot = my_dt.melt("t_val",var_name="lat_type",value_name="lat")
            sns.scatterplot(ax=axis[i],data=to_plot,x="t_val",y="lat",hue="lat_type", style="lat_type")
            axis[i].set_xlabel('Time [ns]')
            axis[i].set_ylabel('Number of cycles')
            axis[i].set_title(chan)
            if(chan=="AW"):
                axis[i].axhline(y=72,xmin=0,xmax=to_plot["t_val"].max())
            if(chan=="W"):
                axis[i].axhline(y=64,xmin=0,xmax=to_plot["t_val"].max())
            i = i+1
    plt.show()
                  
data = pd.read_csv("traces_LAT_0.dat", delimiter=',', sep='\n')
data['TOT'] = data['ACC'] + data['LAT']
print(data["Channel"].value_counts())
chans = ["AW","W","B"]
print_channel(data,chans)
chans = ["AR","R"]
print_channel(data,chans)

