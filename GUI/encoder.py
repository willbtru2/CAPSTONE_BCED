#==========================   Simple Parity Check   ======================#####

# For parity check, codeword_size is message_size + 1, handled in UI.
def encode_parity(message,parity_type="even"):
    count = message.count("1")
    
    if parity_type == "even":
        parity = count % 2
    elif parity_type == "odd":
        parity = (count + 1) % 2        
    else:
        raise ValueError("Parity type must be 'even' or 'odd'.")
        return
    return str(parity) + message



#==========================   Non-Cyclic Hamming   =======================#####
def create_empty_codeword(codeword_size):
    return [None] * codeword_size

def get_data_size(codeword_size):
    parity_count = 0
    parity_position = 1
    while parity_position <= codeword_size:
        parity_count += 1
        parity_position *= 2
    return codeword_size - parity_count

def get_block_count(message_length,data_size):
    return (message_length + data_size - 1) // data_size

def split_message_into_blocks(message,data_size):
    blocks=[]
    for start in range(0,len(message),data_size):
        block = message[start:start + data_size]
        blocks.append(block)
    return blocks

def pad_block(block,data_size):
    padding = data_size - len(block)
    if padding > 0:
        block = block + [0] * padding
    return block

def prepare_data_blocks(message,data_size):
    blocks = split_message_into_blocks(message,data_size)
    prepared_blocks = []
    for block in blocks:
        block = pad_block(block,data_size)
        prepared_blocks.append(block)
    return prepared_blocks
        
def get_data_positions(codeword_size,parity_positions):
    return [
        position
        for position in range(1, codeword_size + 1)
        if position not in parity_positions]

def get_parity_coverage(parity_position,codeword_size):
    return [
        position
        for position in range(1,codeword_size + 1)
        if position & parity_position]

def place_data_bits(codeword,message,parity_positions,codeword_size):
    data_positions = get_data_positions(codeword_size, parity_positions)
    for data_position, bit in zip(data_positions,message):
        codeword[data_position - 1] = bit
    return codeword

def calculate_parity_bit(codeword,parity_position,codeword_size):
    coverage = get_parity_coverage(parity_position,codeword_size)
    ones = sum(
        codeword[position - 1]
        for position in coverage
        if codeword[position -1] is not None)
    return ones % 2

def place_parity_bit(codeword,parity_position,codeword_size):
    parity_bit = calculate_parity_bit(codeword, parity_position,codeword_size)
    codeword[parity_position - 1] = parity_bit
    return codeword

def place_all_parity_bits(codeword,parity_positions,codeword_size):
    for parity_position in parity_positions:
        codeword = place_parity_bit(codeword, parity_position,codeword_size)
    return codeword

def encode_hamming_block(message_block,codeword_size):
    parity_positions = []
    parity_position = 1
    while parity_position <= codeword_size:
        parity_positions.append(parity_position)
        parity_position *= 2
    codeword = create_empty_codeword(codeword_size)
    codeword = place_data_bits(codeword, message_block, parity_positions, codeword_size)
    codeword = place_all_parity_bits(codeword, parity_positions, codeword_size)
    return codeword

def encode_hamming(message,codeword_size):
    data_size = get_data_size(codeword_size)
    data_blocks = prepare_data_blocks(message, data_size)
    encoded_data = []
    for block in data_blocks:
        codeword = encode_hamming_block(block, codeword_size)
        encoded_data.extend(codeword)
    return encoded_data
    
#============================   Cyclic Hamming   =========================#####



#=========================   Binary Golay (23,12)   ======================#####



    
