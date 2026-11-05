#==========================   Simple Parity Check   ======================#####
def parity_compare(codeword,parity_type="even"):
    count = sum(int(bit) for bit in codeword)
        
    if parity_type == "even":
        return count % 2 == 0
    elif parity_type == "odd":
        return count % 2 == 1
    else:
        raise ValueError("Parity type must be 'even' or 'odd'.")


#==========================   Non-Cyclic Hamming   =======================#####
def split_into_blocks(received_data,codeword_size):
    blocks=[]
    for start in range(0,len(received_data),codeword_size):
        block = received_data[start:start + codeword_size]
        blocks.append(block)
    return blocks

def get_parity_positions(codeword_size):
    parity_positions = []
    parity_position = 1
    while parity_position <= codeword_size:
        parity_positions.append(parity_position)
        parity_position *= 2
        
    return parity_positions

def get_parity_coverage(parity_position, codeword_size):
    return [
        position
        for position in range(1, codeword_size + 1)
        if position & parity_position]

def calculate_syndrome(codeword,codeword_size):
    parity_positions = get_parity_positions(codeword_size)
    syndrome = 0
    for parity_position in parity_positions:
        coverage = get_parity_coverage(parity_position,codeword_size)
        parity = sum(
            codeword[position - 1]
            for position in coverage) % 2
        if parity:
            syndrome += parity_position
    return syndrome

def correct_error(codeword,syndrome):
    if syndrome == 0:
        return codeword
    codeword[syndrome - 1] ^= 1
    return codeword

def get_error_position(syndrome):
    if syndrome == 0:
        return None
    return syndrome

def get_data_size(codeword_size):
    parity_count = 0
    parity_position = 1
    while parity_position <= codeword_size:
        parity_count += 1
        parity_position *= 2
    return codeword_size - parity_count

def extract_data_bits(codeword, codeword_size):
    parity_positions = get_parity_positions(codeword_size)
    data_bits = []
    for position in range(1, codeword_size + 1):
        if position not in parity_positions:
            data_bits.append(codeword[position - 1])
    return data_bits

def get_real_data_count(message_length,data_size,block_number):
    start = (block_number * data_size)
    remaining = (message_length - start)
    if remaining >= data_size:
        return data_size
    return max(remaining,0)

def is_data_position(position,codeword_size):
    parity_positions = get_parity_positions(codeword_size)
    return position not in parity_positions

def is_padding_position(position,codeword_size,real_data_count):
    if not is_data_position(position, codeword_size):
        return False
    parity_positions = get_parity_positions(codeword_size)
    data_positions = [
        position
        for position in range(1,codeword_size + 1)
        if position not in parity_positions]
    data_index = data_positions.index(position)
    return data_index >= real_data_count

def decode_hamming_block(codeword,codeword_size):
    syndrome = calculate_syndrome(codeword, codeword_size)
    corrected_codeword = codeword.copy()
    corrected_codeword = correct_error(corrected_codeword, syndrome)
    data_bits = extract_data_bits(corrected_codeword, codeword_size)
    error_position = get_error_position(syndrome)
    return data_bits, error_position

def decode_hamming(received_data,codeword_size,message_length):
    blocks = split_into_blocks(received_data, codeword_size)
    decoded_data = []
    error_positions = []
    data_size = get_data_size(codeword_size)
    for block_number, block in enumerate(blocks):
        data_bits, error_position = decode_hamming_block(block, codeword_size)
        decoded_data.extend(data_bits)
        real_data_count = get_real_data_count(message_length, data_size, block_number)
        if (error_position is not None and is_padding_position(error_position, codeword_size, real_data_count)):
            error_position = None   
        error_positions.append(error_position)
    decoded_data = decoded_data[:message_length]
    return decoded_data, error_positions



    
#============================   Cyclic Hamming   =========================#####



#=========================   Binary Golay (23,12)   ======================#####


    
