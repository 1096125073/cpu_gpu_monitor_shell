from time import strptime
import numpy as np
import matplotlib.pylab as plt
from argparse import ArgumentParser

header = ["Host Memory(g)", "CPU(%)", "GPU Memory(M)", "GPU(%)"]
colors = ['royalblue', 'lime', 'darkorange', 'tomato']


def argument_parser():
    parser = ArgumentParser(description="visualize log file.")
    parser.add_argument("-n", type=int, help="sample n records to draw.")
    parser.add_argument("log_file", type=str, help="the log file to draw.")
    return parser.parse_args()


def read_log_file(file):
    """
    :param file: log file path
    :return: tuple(timestamp,resource)
    """
    timestamp = []
    resource = []
    time_format = "%Y-%m-%d %H:%M:%S"

    with open(file, "rt", encoding="utf-8") as f:
        for line in f.readlines()[1:]:  # skip first row
            filedes = line.strip().split()
            time_filed = " ".join(filedes[:2])
            t = strptime(time_filed, time_format)
            timestamp.append("{:02}-{:02} {:02}:{:02}".format(t.tm_mon, t.tm_mday, t.tm_hour, t.tm_min))
            host_memory = filedes[2]
            if 'g' not in host_memory:  # convert kb to Gb
                host_memory = float(host_memory) / (1024.0 * 1024.0)
                host_memory = round(host_memory, 2)
            else:
                host_memory = float(host_memory[:-1])  # remove suffix 'g'
            filedes[2] = host_memory
            resource.append([float(x) for x in filedes[2:]])
    return timestamp, resource


def draw_resource(y, ticks=None, label=None):
    """
    draw function
    :param y:
    :param ticks:
    :param label:
    :return:
    """
    fg, axes = plt.subplots(2, 2, dpi=100)
    axes = np.ravel(axes)
    for i in range(4):
        ax = axes[i]
        data = y[:, i]
        ax.set_title(header[i])
        ax.plot(data, c=colors[i])
        if ticks is not None and label is not None:
            ax.set_xticks(ticks, label)
    plt.tight_layout()
    plt.show()


if __name__ == "__main__":
    args = argument_parser()
    ts, rs = read_log_file(args.log_file)
    ts = np.array(ts, dtype=str)
    rs = np.array(rs)
    n = args.n if args.n is not None else len(ts)
    rs_select_index = np.linspace(0, len(rs) - 1, n, dtype=np.int32)  # sample n records to draw
    ts_select_index = np.linspace(0, n - 1, min(n, 3), dtype=np.int32)
    draw_ts = ts[rs_select_index][ts_select_index]
    draw_rs = rs[rs_select_index]
    draw_resource(draw_rs, ts_select_index, draw_ts)
