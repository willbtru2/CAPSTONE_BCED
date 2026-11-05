import tkinter as tk
from tkinter import ttk
import styles


class ChannelSimulator:
    def __init__(self,encoded_data,codeword_size,on_complete):#,parent)
        #self.parent = parent
        self.encoded_data = encoded_data
        self.codeword_size = codeword_size
        self.on_complete = on_complete
        
        self.blocks = self.split_into_blocks()
        self.received_blocks = [block.copy() for block in self.blocks]
        
        self.window = tk.Tk()
        self.window.title("Channel Simulator")
        self.window.geometry("900x500+1040+160")
        self.window.minsize(600,400)
        
        self.style = ttk.Style()
        styles.configure_styles(self.style)
        
        self.create_widgets()
        
    def create_widgets(self):
        heading = ttk.Label(self.window,text="Channel Simulator")
        heading.pack(fill="x",padx=10,pady=10)
        
        self.channel_canvas = tk.Canvas(self.window)
        self.channel_canvas.pack(fill="both",expand=True,padx=10,pady=5)
        self.channel_frame = ttk.Frame(self.channel_canvas)
        self.channel_canvas.create_window((0,0),window=self.channel_frame,anchor="nw")
        self.channel_frame.bind("<Configure>",self.update_scroll_region)
        self.channel_canvas.bind("<MouseWheel>",self.scroll_vertical)
        self.channel_canvas.bind("<Shift-MouseWheel>",self.scroll_horizontal)        
        
        clear_button = ttk.Button(self.window,text="Clear Errors",command=self.clear_errors)
        clear_button.pack(pady=10)
        send_button = ttk.Button(self.window,text="Send to Decoder",command=self.send_to_decoder)
        send_button.pack(pady=10)
        self.display_blocks()

        
    def display_blocks(self):
        for block_number, block in enumerate(self.blocks, start=1):
            block_frame = ttk.LabelFrame(self.channel_frame,text=f"Block {block_number}")
            block_frame.pack(fill="x",padx=2,pady=5)
            for bit_position in range(len(block) - 1, -1, -1):
                bit_frame = ttk.Frame(block_frame)
                bit_frame.pack(side="left",padx=2,pady=5)
                bit_label = ttk.Label(bit_frame,text=str(self.received_blocks[block_number - 1][bit_position]),width=3,anchor="center")
                bit_label.pack()
                bit_label.bind("<Button-1>",lambda event,block=block_number - 1,position=bit_position:self.flip_bit(block,position))
                position_label = ttk.Label(bit_frame,text=f"Bit {bit_position + 1}",width=5,anchor="center")
                position_label.pack()
            
    def update_scroll_region(self,event=None):
        self.channel_canvas.configure(scrollregion=self.channel_canvas.bbox("all"))
    
    def scroll_vertical(self,event):
        self.channel_canvas.yview_scroll(-1 *  int(event.delta / 120),"units")
    
    def scroll_horizontal(self,event):
        self.channel_canvas.xview_scroll(-1 * int(event.delta / 120),"units")
    
###########################################################################
############################# Helpers Stuff ###############################
###########################################################################
    def split_into_blocks(self):
        if self.codeword_size == 0:
            return [[int(bit) for bit in self.encoded_data]]
        
        blocks = []
        for start in range(0,len(self.encoded_data),self.codeword_size):
            block = self.encoded_data[start:start + self.codeword_size]
            block = [int(bit) for bit in block]
            blocks.append(block)
        return blocks

    def flip_bit(self,block_number,bit_position):
        self.received_blocks[block_number][bit_position] ^= 1
        self.update_blocks()
        
    def update_blocks(self):
        for widget in self.channel_frame.winfo_children():
            if isinstance(widget,ttk.LabelFrame):
                widget.destroy()
        self.display_blocks()

    def clear_errors(self):
        self.received_blocks = [
            block.copy() 
            for block in self.blocks]
        self.update_blocks()
        
    def send_to_decoder(self):
        received_data = [
            bit
            for block in self.received_blocks
            for bit in block]
        self.on_complete(received_data)
        self.window.destroy()
    
###########################################################################
#############################      Main      ##############################
###########################################################################
    def run(self):
        self.window.mainloop()


encoded_data = [1,0,1,0,1,1,1,0,1,0,0,0,1,1,0,1,
                     1,0,1,0,1,0,1,0,1,0,1,1,0,0,1,1,
                     0,1,0,1,0,1,1,0,1,0,1,0,1,0,1,1,
                     0,1,0,0,1,0,1,0,1,0,1,0,1,0,1,1,1,0,0]
codeword_size = 15  
#app = ChannelSimulator(encoded_data,codeword_size,channel_complete)
#app.run()        
