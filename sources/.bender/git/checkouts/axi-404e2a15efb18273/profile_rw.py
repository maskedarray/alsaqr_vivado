import numpy as np
import matplotlib.pyplot as plt

data0 = np.loadtxt("traces_ID_0.dat", delimiter=",", dtype='str' ,skiprows=1)
data1 = np.loadtxt("traces_ID_1.dat", delimiter=",", dtype='str' ,skiprows=1)

data0r = np.delete(data0, np.where(data0[:,2]=="W"),0)
data0w = np.delete(data0, np.where(data0[:,2]=="R"),0)
data1r = np.delete(data1, np.where(data1[:,2]=="W"),0)
data1w = np.delete(data1, np.where(data1[:,2]=="R"),0)

fig = plt.figure()
ax0 = fig.add_subplot(223)

ax0.plot(data0w[:,1].astype(float), data0w[:,7].astype(float),'--o', color='red', label='AW Master 0. Num tests %d, B %d' %(len(data0w[:,1].astype(float)), data0w[0,5].astype(float)) )
ax0.plot(data1w[:,1].astype(float), data1w[:,7].astype(float),'--x', color='cyan', label='AW Master 1. Num tests %d, B %d' %(len(data1w[:,1].astype(float)), data1w[0,5].astype(float)) )

mean0w = np.mean(data0w[:,7].astype(float))
mean1w = np.mean(data1w[:,7].astype(float))

min_time = np.min([data0w[-1,1].astype(float),data1w[-1,1].astype(float)])
max_time = np.max([data0w[0,1].astype(float),data1w[0,1].astype(float)])

ax0.hlines(mean0w,min_time,max_time, color='red')
ax0.hlines(mean1w,min_time,max_time, color='cyan')

plt.ylabel('Util')
plt.xlabel('Time [ns]')
plt.legend()

ax2 = fig.add_subplot(221)

ax2.plot(data0w[:,0].astype(float), data0w[:,4].astype(float),'o', color='red', label='AW Master 0. Num tests %d, B %d' %(len(data0w[:,0].astype(float)), data0w[0,5].astype(float)) )
ax2.plot(data1w[:,0].astype(float), data1w[:,4].astype(float),'x', color='cyan', label='AW Master 1. Num tests %d, B %d' %(len(data1w[:,0].astype(float)), data1w[0,5].astype(float)) )
plt.ylabel('AW_valid latency')
plt.xlabel('Time [ns]')
plt.legend()

ax1 = fig.add_subplot(224)

ax1.plot(data0r[:,1].astype(float), data0r[:,7].astype(float),'--o', color='green', label='AR Master 0. Num tests %d, B %d' %(len(data0r[:,1].astype(float)), data0r[0,5].astype(float)) )
ax1.plot(data1r[:,1].astype(float), data1r[:,7].astype(float),'--x', color='blue', label='AR Master 1. Num tests %d, B %d' %(len(data1r[:,1].astype(float)), data1r[0,5].astype(float)) )

mean0r = np.mean(data0r[:,7].astype(float))
mean1r = np.mean(data1r[:,7].astype(float))

max_time = np.max([data0r[-1,1].astype(float),data1r[-1,1].astype(float)])
min_time = np.min([data0r[0,1].astype(float),data1r[0,1].astype(float)])
ax1.hlines(mean0r,min_time,max_time, color='blue')
ax1.hlines(mean1r,min_time,max_time, color='black')

plt.ylabel('Util')
plt.xlabel('Time [ns]')
plt.legend()

ax3 = fig.add_subplot(222)

ax3.plot(data0r[:,0].astype(float), data0r[:,4].astype(float),'o', color='green', label='AR Master 0. Num tests %d, B %d' %(len(data0w[:,0].astype(float)), data0w[0,5].astype(float)) )
ax3.plot(data1r[:,0].astype(float), data1r[:,4].astype(float),'x', color='blue', label='AR Master 1. Num tests %d, B %d' %(len(data1w[:,0].astype(float)), data1w[0,5].astype(float)) )
print(data0r[:,0].astype(float))
print(data0r[:,4].astype(float))
print(data1r[:,0].astype(float))
print(data1r[:,4].astype(float))

plt.ylabel('AR_ready latency')
plt.xlabel('Time [ns]')
plt.legend()

plt.show()
