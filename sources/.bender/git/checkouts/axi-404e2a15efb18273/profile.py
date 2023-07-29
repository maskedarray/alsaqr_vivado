import numpy as np
import matplotlib.pyplot as plt

data0 = np.loadtxt("traces_ID_0.dat", delimiter="," ,skiprows=1)
data1 = np.loadtxt("traces_ID_1.dat", delimiter="," ,skiprows=1)

d0reads = np.delete(data0, np.where(data0[:,1]==0),0)
d0writes = np.delete(data0, np.where(data0[:,1]==1),0)
d1reads = np.delete(data1, np.where(data1[:,1]==0),0)
d1writes = np.delete(data1, np.where(data1[:,1]==1),0)
        
fig = plt.figure()
ax0 = fig.add_subplot(111)

ax0.plot(data0[:,0], data0[:,6],'--o', color='red', label='ID 0. Num tests %d, B %d' %(len(data0[:,0]), data0[0,4]) )
ax0.plot(data1[:,0], data1[:,6],'--x', color='cyan', label='ID 1. Num tests %d, B %d' %(len(data1[:,0]), data1[0,4]) )

mean0 = np.mean(data0[:,6])
mean1 = np.mean(data1[:,6])

max_time = np.max([data0[-1,0],data1[-1,0]])

ax0.hlines(mean0,0,max_time, color='red')
ax0.hlines(mean1,0,max_time, color='cyan')

plt.ylabel('Util')
plt.xlabel('Time [ns]')
plt.legend()
plt.show()
