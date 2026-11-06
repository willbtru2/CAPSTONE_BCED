
import numpy as np

def hamming_matrices(m):
    n = 2**m - 1
    k = n - m

    # All nonzero m-bit columns, in a consistent order
    columns = [
        np.array([(value >> bit) & 1 for bit in range(m)], dtype=np.uint8)
        for value in range(1, 2**m)
        ]

    # Put the m unit vectors at the end so H has an identity block there.
    unit_vectors = [
        np.eye(m, dtype=np.uint8)[:, i] for i in range(m)
        ]
    parity_columns = [
        col for col in columns
        if not any(np.array_equal(col, unit) for unit in unit_vectors)
        ]
    ordered_columns = parity_columns + unit_vectors

    H = np.column_stack(ordered_columns)
    P = H[:, :k].T
    G = np.concatenate((np.eye(k, dtype=np.uint8), P), axis=1)

    return G, H

G7,  H7  = hamming_matrices(3) 
G15, H15 = hamming_matrices(4)
G31, H31 = hamming_matrices(5)  # shapes: (26, 31), (5, 31)
G63, H63 = hamming_matrices(6)  # shapes: (57, 63), (6, 63)


def encode(data, G):
    data = np.asarray(data, dtype=np.uint8).reshape(1, -1)
    if data.shape[1] != G.shape[0]:
        raise ValueError(f"Expected {G.shape[0]} data bits")
    return (data @ G) % 2

data74   = np.array([1,1,0,1])
data1511 = np.array([1,0,0,1,1,0,1,1,0,1,0]) 
data3126 = np.array([0,1,1,0,0,1,0,1,0,1,1,0,0,1,0,1,0,1,0,1,0,1,0,1,0,1])
data6357 = np.array([0,1,1,0,0,1,0,1,0,1,1,0,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,1,0,0,1,0,1,0,1,1,0,0,1,0,1,0,1,0,1,0,1,0,1,0,1,1,0,0,1,0])

codeword74 = encode(data74, G7)
codeword15 = encode(data1511, G15)
codeword31 = encode(data3126, G31)
codeword63 = encode(data6357, G63)


R7  = codeword74 ^ [0,0,0,1,0,0,0]
R15 = codeword15 ^ [0,0,0,0,0,0,0,0,0,0,0,0,0,0,1]
R31 = codeword31 ^ [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1]
R63 = codeword63 ^ [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1]


S7  = R7  @ H7.T  % 2
S15 = R15 @ H15.T % 2
S31 = R31 @ H31.T % 2
S63 = R63 @ H63.T % 2

print(S7)
print(S15)
print(S31)
print(S63)

print(G7)
print(G15)
print(G31)
with np.printoptions(linewidth=400, threshold=np.inf):
    print(G63)

