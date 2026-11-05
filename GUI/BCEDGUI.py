
import tkinter as tk
from tkinter import ttk
import styles
import encoder
import decoder
import channel_sim
import random

class BlockCodeGUI:
    def __init__(self):
        # Window
        self.window = tk.Tk()
        self.style=ttk.Style()
        styles.configure_styles(self.style)
        self.window.configure(background="black")

        self.binary_font=("Consolas",11)
        self.window.title(
            "Block Code Encoder / Decoder"
            )
        self.window.geometry("880x980+160+160")
        self.window.minsize(880,980)
        self.window.maxsize(880,980)
        self.window.columnconfigure(0,weight=1)
        # Variables
        self.encoding = tk.StringVar(value="Parity Check")
        self.encoding.trace_add("write",self.encoding_changed)
        self.encoding_align = tk.StringVar(value="even")
        self.encoding_function = tk.StringVar(value="sec")
        self.codeword_size = tk.IntVar(value=0)
        
        self.message_size = tk.IntVar(value=4)
        self.message_input = tk.StringVar()
        self.message_input.trace_add("write",self.message_changed)
        self.message_source="user"
        self.message = ""
        self.message_length = 0
        
        self.encoded_data=""
        self.received_data=[]
        self.decoded_data=""
        self.message_valid=False
        self.encoded_valid=False
        self.received_valid=False
        
        self.status_text=tk.StringVar(value="Message Status: Awaiting message...")
        self.scheme_select_text=tk.StringVar(value="Current (n, k): (7, 4).")        
        
        self.original_output    = tk.StringVar()
        self.encoded_output     = tk.StringVar()
        self.received_output    = tk.StringVar()
        self.decoded_output     = tk.StringVar()
        self.errors_output      = tk.StringVar()
        # Frames
        self.create_config_frame()
        self.create_encoding_frame()
        self.create_scheme_frame()
        self.create_parity_frame()
        self.create_scheme_select_frame()
        self.create_message_frame()
        self.create_message_size_controls()
        self.create_operation_frame()
        self.create_message_status_frame()
        self.create_output_frame()
        self.create_fpga_frame()
        #self.window.rowconfigure(5,weight=1)
        self.window.bind("<Key>",self.handle_keyboard)

    ###########################################################################
    ############################## Frame Stuff ################################
    ###########################################################################    
    def create_config_frame(self):
        self.config_frame = ttk.Frame(self.window,style="ConFrame.TFrame")
        self.config_frame.grid(row=0,column=0,columnspan=2,padx=10,pady=5,sticky="ew")
        self.config_frame.columnconfigure(1,weight=1)
        
        ttk.Label(
            self.config_frame,
            text="Configuration",
            anchor="center",
            style="ConHeading.TLabel").grid(row=0,column=0,columnspan=3,padx=1,pady=1,sticky="ew")
        
    def create_encoding_frame(self):
        self.encoding_frame = ttk.Frame(self.config_frame,style="EncFrame.TFrame",relief="solid")
        self.encoding_frame.grid(row=1,column=0,padx=10,pady=10,sticky="ew")        
        encoding_label=ttk.Label(
            self.encoding_frame,
            text="Encoding Scheme:",
            style="ConLabel.TLabel"
            )
        encoding_label.grid(row=0,column=0,padx=10,pady=10,sticky="ew")
        
        self.encoding_box = ttk.Combobox(
            self.encoding_frame,
            values=[
                "Parity Check",
                "Non-Cyclic Hamming",
                "Cyclic Hamming",
                "Binary Golay"
                ],
            textvariable=self.encoding,
            style="EncodeBox.TCombobox",
            state="readonly"
        )
        self.encoding_box.grid(row=0,column=1,padx=10,pady=10,sticky="ew")
            
    def create_scheme_frame(self):
        self.scheme_frame = ttk.Frame(self.config_frame,style="EncFrame.TFrame",relief="solid")
        self.scheme_frame.grid(row=1,column=1,padx=5,pady=1,sticky="ew")
        self.scheme_frame.grid_remove()        
        
        self.sevenfour_button=ttk.Button(
            self.scheme_frame,
            text="(7, 4)",
            command=lambda: self.select_sevenfour())
        self.sevenfour_button.grid(row=0,column=0,padx=10,pady=10,sticky="ew")
        
        self.fifteeneleven_button=ttk.Button(
            self.scheme_frame,
            text="(15, 11)",
            command=lambda: self.select_fifteeneleven())
        self.fifteeneleven_button.grid(row=0,column=1,padx=10,pady=10,sticky="ew")
        
        self.thirtytwenty_button=ttk.Button(
            self.scheme_frame,
            text="(31, 26)",
            command=lambda: self.select_thirtytwenty())
        self.thirtytwenty_button.grid(row=0,column=2,padx=10,pady=10,sticky="ew")
        
        self.sixtyfifty_button=ttk.Button(
            self.scheme_frame,
            text="(63, 57)",
            command=lambda: self.select_sixtyfifty())
        self.sixtyfifty_button.grid(row=0,column=3,padx=10,pady=10,sticky="ew")        

    def create_scheme_select_frame(self):
        self.scheme_select_frame = ttk.Frame(self.config_frame,style="EncFrame.TFrame")
        self.scheme_select_frame.grid(row=2,column=1,padx=10,pady=5,sticky="ew")
        self.scheme_select_frame.grid_remove()
        #self.scheme_select_frame.columnconfigure(1,weight=1)
        #self.scheme_select_frame.columnconfigure(4,weight=1)
        
        self.scheme_select_label = ttk.Label(
            self.scheme_select_frame,
            style="SchLabel.TLabel",
            anchor="center",
            textvariable=self.scheme_select_text
            )
        self.scheme_select_label.grid(row=0,column=1,columnspan=6,padx=10,pady=10,sticky="ew")
        
    def create_parity_frame(self):
        self.parity_frame = ttk.Frame(self.config_frame,style="EncFrame.TFrame")
        self.parity_frame.grid(row=2,column=0,padx=10,pady=5,sticky="ew")
        #self.parity_frame.columnconfigure(1,weight=1)
        #self.parity_frame.columnconfigure(4,weight=1)
        self.parity_label = ttk.Label(
            self.parity_frame,
            text="Select Parity Alignment:",
            style="ConLabel.TLabel").grid(row=0,column=0,padx=10,pady=10,sticky="w")
        self.even_button=ttk.Button(
            self.parity_frame,
            text="Even Parity",
            command=lambda: self.set_parity("even")
            )
        self.even_button.grid(row=0,column=1,padx=10,pady=10,sticky="ew")
        self.odd_button=ttk.Button(
            self.parity_frame,
            text="Odd Parity",
            command=lambda: self.set_parity("odd")
            )
        self.odd_button.grid(row=0,column=2,padx=10,pady=10,sticky="ew")        
            
    def create_message_frame(self):
        self.message_frame = ttk.Frame(self.window,style="MsgFrame.TFrame")
        self.message_frame.grid(row=1,column=0,columnspan=2,padx=10,pady=5,sticky="ew")
        self.message_frame.columnconfigure(1,weight=1)
        #self.message_frame.columnconfigure(1,weight=1)
        ttk.Label(
            self.message_frame,
            text="Input",
            anchor="center",
            style="MsgHeading.TLabel").grid(row=0,column=0,columnspan=5,padx=1,pady=1,sticky="ew")
        
        message_label = ttk.Label(
            self.message_frame,
            text="Message bits:",
            style="MsgLabel.TLabel",
            width=15
            )
        message_label.grid(row=1,column=0,padx=10,pady=10)
        self.message_entry = ttk.Entry(
            self.message_frame,
            textvariable=self.message_input
            )
        self.message_entry.grid(row=1,column=1,padx=0,pady=10,sticky="ew")
        self.message_accept_button = ttk.Button(
            self.message_frame,
            text="Confirm",
            style="UploadButton.TButton",
            command=self.validate_message
            )
        self.message_accept_button.grid(row=1,column=3,padx=10,pady=10,sticky="ew")
        


        self.clear_button=ttk.Button(
            self.message_frame,
            text="Clear",
            command=self.clear_message)
        self.clear_button.grid(row=1,column=4,padx=10,pady=10,sticky="ew")
    
    # Encode / Decode Buttons
    def create_operation_frame(self):
        self.operation_frame = ttk.Frame(self.window,style="OpsFrame.TFrame")
        
        self.operation_frame.grid(row=2,column=0,columnspan=2,padx=10,pady=5,sticky="ew")
        self.operation_frame.columnconfigure(0,weight=1)
        self.operation_frame.columnconfigure(2,weight=1)
        self.operation_frame.columnconfigure(4,weight=1)
        
        operation_title=ttk.Label(
            self.operation_frame,
            text="Operations",
            anchor="center",
            style="OpsHeading.TLabel")
        operation_title.grid(row=0,column=0,columnspan=5,padx=1,pady=1,sticky="ew")
        
        self.encode_button = ttk.Button(
            self.operation_frame,
            text="Encode",
            command=self.encode_message,
            state="disabled",
            style="EncodeButton.TButton"
            )
        self.encode_button.grid(row=2,column=1,padx=10,pady=20,sticky="ew")

        self.decode_button = ttk.Button(
            self.operation_frame,
            text="Decode",
            command=self.decode_message,
            state="disabled",
            style="DecodeButton.TButton"
            )
        self.decode_button.grid(row=2,column=3,padx=10,pady=20,sticky="ew")
        
    def create_message_status_frame(self):
        self.message_status_frame = ttk.Frame(self.operation_frame,style="StsFrame.TFrame")
        self.message_status_frame.grid(row=1,column=0,columnspan=6,padx=10,pady=10,sticky="ew")
        self.message_status_frame.columnconfigure(0,weight=1)
        self.message_status_label = ttk.Label(
            self.message_status_frame,
            style="StsLabel.TLabel",
            anchor="center",
            textvariable=self.status_text
            )
        self.message_status_label.grid(row=0,column=0,columnspan=2,padx=10,pady=10,sticky="ew")        
        
        
    # Output
    def create_output_frame(self):
        self.output_frame = ttk.Frame(self.window,style="OutFrame.TFrame")
        self.output_frame.grid(row=4,column=0,padx=10,pady=5,sticky="ew")
        results_title=ttk.Label(
            self.output_frame,
            text="Software Results",
            anchor="center",
            style="OutHeading.TLabel")
        results_title.grid(row=0,column=0,columnspan=8,padx=3,pady=3,sticky="ew")
        self.output_frame.columnconfigure(1,weight=1)
        self.output_frame.rowconfigure(1,weight=1)
        self.output_frame.rowconfigure(3,weight=1)
        self.output_frame.rowconfigure(5,weight=1)
        self.output_frame.rowconfigure(7,weight=1)
        
        original_label = ttk.Label(
            self.output_frame,
            text="Original Message:",
            style="OutLabel.TLabel"
            )
        original_label.grid(row=1,column=0,padx=10,pady=10,sticky="ew")
        self.original_text = tk.Text(
            self.output_frame,
            height=2,
            width=60,
            wrap="none",
            font=self.binary_font
            )
        self.original_scrollbar=ttk.Scrollbar(
            self.output_frame,
            orient="horizontal",
            command=self.original_text.xview
            )
        self.original_text.configure(xscrollcommand=self.original_scrollbar.set)
        self.original_text.grid(row=1,column=1,padx=10,pady=10,sticky="nsew")
        self.original_scrollbar.grid(row=2,column=1,sticky="ew")
        self.original_text.config(state="disabled")
        
        encoded_label = ttk.Label(
            self.output_frame,
            text="Encoded Message:",
            style="OutLabel.TLabel"
            )
        encoded_label.grid(row=3,column=0,padx=10,pady=10,sticky="ew")
        self.encoded_text = tk.Text(
            self.output_frame,
            height=2,
            width=60,
            wrap="none",
            font=self.binary_font
            )
        self.encoded_scrollbar=ttk.Scrollbar(
            self.output_frame,
            orient="horizontal",
            command=self.encoded_text.xview
            )
        self.encoded_text.configure(xscrollcommand=self.encoded_scrollbar.set)
        self.encoded_text.grid(row=3,column=1,padx=10,pady=10,sticky="nsew")
        self.encoded_scrollbar.grid(row=4,column=1,sticky="ew")
        self.encoded_text.config(state="disabled")

        received_label = ttk.Label(
            self.output_frame,
            text="Received Message:",
            style="OutLabel.TLabel"
            )
        received_label.grid(row=5,column=0,padx=10,pady=10,sticky="ew")
        self.received_text = tk.Text(
            self.output_frame,
            height=2,
            width=60,
            wrap="none",
            font=self.binary_font)
        self.received_scrollbar=ttk.Scrollbar(
            self.output_frame,
            orient="horizontal",
            command=self.received_text.xview
            )
        self.received_text.configure(xscrollcommand=self.received_scrollbar.set)
        self.received_text.grid(row=5,column=1,padx=10,pady=10,sticky="nsew")
        self.received_scrollbar.grid(row=6,column=1,sticky="ew")
        self.received_text.config(state="disabled")

        decoded_label = ttk.Label(
            self.output_frame,
            text="Decoded Message:",
            style="OutLabel.TLabel"
            )
        decoded_label.grid(row=7,column=0,padx=10,pady=10,sticky="ew")
        self.decoded_text = tk.Text(
            self.output_frame,
            height=2,
            width=60,
            wrap="none",
            font=self.binary_font
            )
        self.decoded_scrollbar=ttk.Scrollbar(
            self.output_frame,
            orient="horizontal",
            command=self.decoded_text.xview
            )
        self.decoded_text.configure(xscrollcommand=self.decoded_scrollbar.set)
        self.decoded_text.grid(row=7,column=1,padx=10,pady=10,sticky="nsew")
        self.decoded_scrollbar.grid(row=8,column=1,sticky="ew")
        self.decoded_text.config(state="disabled")

        analysis_label = ttk.Label(
            self.output_frame,
            text="Errors Report:",
            style="OutLabel.TLabel"
            )
        analysis_label.grid(row=9,column=0,padx=10,pady=10,sticky="ew")
        self.analysis_text = tk.Text(
            self.output_frame,
            height=2,
            width=60,
            wrap="word",
            font=self.binary_font
            )
        self.analysis_vscrollbar=ttk.Scrollbar(
            self.output_frame,
            orient="vertical",
            command=self.analysis_text.yview
            )
        self.analysis_scrollbar=ttk.Scrollbar(
            self.output_frame,
            orient="horizontal",
            command=self.analysis_text.xview
            )
        self.analysis_text.configure(yscrollcommand=self.analysis_vscrollbar.set)
        self.analysis_text.configure(xscrollcommand=self.analysis_scrollbar.set)
        self.analysis_text.grid(row=9,column=1,padx=10,pady=10,sticky="nsew")
        self.analysis_vscrollbar.grid(row=9,column=2,sticky="ns")
        self.analysis_scrollbar.grid(row=10,column=1,sticky="ew")
        self.analysis_text.config(state="disabled")
    
    def create_fpga_frame(self):
        self.fpga_frame_window = tk.Toplevel(self.window)
        self.fpga_frame_window.title("FPGA Results")
        fpga_x = self.window.winfo_x() + 1040
        fpga_y = self.window.winfo_y() + 704
        self.fpga_frame_window.geometry(f"880x436+{fpga_x}+{fpga_y}")
        self.fpga_frame_window.minsize(880,330)
        self.fpga_frame_window.configure(background="black")
        self.fpga_frame_window.columnconfigure(0,weight=1)
        self.fpga_output_frame = ttk.Frame(self.fpga_frame_window,style="FPGAFrame.TFrame")
        self.fpga_output_frame.grid(row=0,column=0,padx=10,pady=5,sticky="ew")
        fpga_results_title=ttk.Label(
            self.fpga_output_frame,
            text="FPGA Results",
            anchor="center",
            style="FPGAHeading.TLabel")
        fpga_results_title.grid(row=0,column=0,columnspan=8,padx=3,pady=3,sticky="ew")
        self.fpga_output_frame.columnconfigure(1,weight=1)
        self.fpga_output_frame.rowconfigure(1,weight=1)
        self.fpga_output_frame.rowconfigure(3,weight=1)
        self.fpga_output_frame.rowconfigure(5,weight=1)
        self.fpga_output_frame.rowconfigure(7,weight=1)
        
        fpga_original_label = ttk.Label(
            self.fpga_output_frame,
            text="Original Message:",
            style="FPGALabel.TLabel"
            )
        fpga_original_label.grid(row=1,column=0,padx=10,pady=10,sticky="ew")
        self.fpga_original_text = tk.Text(
            self.fpga_output_frame,
            height=2,
            width=60,
            wrap="none",
            font=self.binary_font,
            bg="green",
            fg="black"
            )
        self.fpga_original_scrollbar=ttk.Scrollbar(
            self.fpga_output_frame,
            orient="horizontal",
            command=self.original_text.xview
            )
        self.fpga_original_text.configure(xscrollcommand=self.original_scrollbar.set)
        self.fpga_original_text.grid(row=1,column=1,padx=10,pady=10,sticky="nsew")
        self.fpga_original_scrollbar.grid(row=2,column=1,sticky="ew")
        self.fpga_original_text.config(state="disabled")
        
        fpga_encoded_label = ttk.Label(
            self.fpga_output_frame,
            text="Encoded Message:",
            style="FPGALabel.TLabel"
            )
        fpga_encoded_label.grid(row=3,column=0,padx=10,pady=10,sticky="ew")
        self.fpga_encoded_text = tk.Text(
            self.fpga_output_frame,
            height=2,
            width=60,
            wrap="none",
            font=self.binary_font,
            bg="green",
            fg="black"
            )
        self.fpga_encoded_scrollbar=ttk.Scrollbar(
            self.fpga_output_frame,
            orient="horizontal",
            command=self.encoded_text.xview
            )
        self.fpga_encoded_text.configure(xscrollcommand=self.encoded_scrollbar.set)
        self.fpga_encoded_text.grid(row=3,column=1,padx=10,pady=10,sticky="nsew")
        self.fpga_encoded_scrollbar.grid(row=4,column=1,sticky="ew")
        self.fpga_encoded_text.config(state="disabled")

        fpga_received_label = ttk.Label(
            self.output_frame,
            text="Received Message:",
            style="OutLabel.TLabel"
            )
        fpga_received_label.grid(row=5,column=0,padx=10,pady=10,sticky="ew")
        self.fpga_received_text = tk.Text(
            self.output_frame,
            height=2,
            width=60,
            wrap="none",
            font=self.binary_font)
        self.fpga_received_scrollbar=ttk.Scrollbar(
            self.output_frame,
            orient="horizontal",
            command=self.received_text.xview
            )
        self.fpga_received_text.configure(xscrollcommand=self.received_scrollbar.set)
        self.fpga_received_text.grid(row=5,column=1,padx=10,pady=10,sticky="nsew")
        self.fpga_received_scrollbar.grid(row=6,column=1,sticky="ew")
        self.fpga_received_text.config(state="disabled")

        fpga_decoded_label = ttk.Label(
            self.fpga_output_frame,
            text="Decoded Message:",
            style="FPGALabel.TLabel"
            )
        fpga_decoded_label.grid(row=7,column=0,padx=10,pady=10,sticky="ew")
        self.fpga_decoded_text = tk.Text(
            self.fpga_output_frame,
            height=2,
            width=60,
            wrap="none",
            font=self.binary_font,
            bg="green",
            fg="black"
            )
        self.fpga_decoded_scrollbar=ttk.Scrollbar(
            self.fpga_output_frame,
            orient="horizontal",
            command=self.decoded_text.xview
            )
        self.fpga_decoded_text.configure(xscrollcommand=self.decoded_scrollbar.set)
        self.fpga_decoded_text.grid(row=7,column=1,padx=10,pady=10,sticky="nsew")
        self.fpga_decoded_scrollbar.grid(row=8,column=1,sticky="ew")
        self.fpga_decoded_text.config(state="disabled")

        fpga_analysis_label = ttk.Label(
            self.fpga_output_frame,
            text="Errors detected:",
            style="FPGALabel.TLabel"
            )
        fpga_analysis_label.grid(row=9,column=0,padx=10,pady=10,sticky="ew")
        self.fpga_analysis_text = tk.Text(
            self.fpga_output_frame,
            height=2,
            width=60,
            wrap="word",
            font=self.binary_font,
            bg="green",
            fg="black"
            )
        self.fpga_analysis_vscrollbar=ttk.Scrollbar(
            self.fpga_output_frame,
            orient="vertical",
            command=self.analysis_text.yview
            )
        self.fpga_analysis_scrollbar=ttk.Scrollbar(
            self.fpga_output_frame,
            orient="horizontal",
            command=self.analysis_text.xview
            )
        self.fpga_analysis_text.configure(yscrollcommand=self.analysis_vscrollbar.set)
        self.fpga_analysis_text.configure(xscrollcommand=self.analysis_scrollbar.set)
        self.fpga_analysis_text.grid(row=9,column=1,padx=10,pady=10,sticky="nsew")
        self.fpga_analysis_vscrollbar.grid(row=9,column=2,sticky="ns")
        self.fpga_analysis_scrollbar.grid(row=10,column=1,sticky="ew")
        #self.fpga_analysis_scrollbar.configure(style="CustomScroll.TScrollbar")
        self.fpga_analysis_text.config(state="disabled")
    
    def set_codeword_size(self, size):
        self.codeword_size.set(size)
        
    # Select message size    
    def set_message_size(self, size):
        self.message_size.set(size)
        
        print("Message size set to: ", self.message_size.get())
        self.message_size_label.config(
            text="Current Size: " + str(self.message_size.get()) + " bits")
    def create_message_size_controls(self):
        self.message_button_frame = ttk.Frame(self.message_frame,style="BtnFrame.TFrame")
        self.message_button_frame.grid(row=2,column=0,columnspan=5,padx=1,pady=10,sticky="ew")
        self.message_button_frame.columnconfigure(1,minsize=100)
        select_label = ttk.Label(
            self.message_button_frame,
            text="Select size:",
            style="MsgLabel.TLabel",
            width=15
            )
        select_label.grid(row=0,column=0,padx=10,pady=10,sticky="w")
        sizeFour_button = ttk.Button(
            self.message_button_frame,
            text="4 Bits",
            command=lambda: self.set_message_size(4)
            )
        sizeFour_button.grid(row=0,column=1,padx=10,pady=10,sticky="ew")

        sizeEight_button = ttk.Button(
            self.message_button_frame,
            text="8 Bits",
            command=lambda: self.set_message_size(8)
            )
        sizeEight_button.grid(row=0,column=2,padx=10,pady=10,sticky="ew")

        sizeSixteen_button = ttk.Button(
            self.message_button_frame,
            text="16 Bits",
            command=lambda: self.set_message_size(16)
            )
        sizeSixteen_button.grid(row=0,column=3,padx=10,pady=10,sticky="ew")

        sizeThirtytwo_button = ttk.Button(
            self.message_button_frame,
            text="32 Bits",
            command=lambda: self.set_message_size(32)
            )
        sizeThirtytwo_button.grid(row=0,column=4,padx=10,pady=10,sticky="ew")

        sizeSixtyfour_button = ttk.Button(
            self.message_button_frame,
            text="64 Bits",
            command=lambda: self.set_message_size(64)
            )
        sizeSixtyfour_button.grid(row=0,column=5,padx=17,pady=10,sticky="ew")
        self.message_size_label = ttk.Label(
            self.message_button_frame,
            text="Current Size: " + str(self.message_size.get()) + " bits",
            style="MsgLabel.TLabel",
            anchor="center")
        self.message_size_label.grid(row=0,column=6,padx=15,pady=10,sticky="nse")
        self.generate_button = ttk.Button(
            self.message_button_frame,
            text="Generate",
            style="GenerateButton.TButton",
            command=self.generate_bits
            )
        self.generate_button.grid(row=3,column=3,padx=0,pady=10,sticky="ew")
        
        
    ###########################################################################
    ########################### Operation Stuff ###############################
    ###########################################################################
    # Rand    
    def generate_bits(self):
        print("Generate button pressed.")
        bits = ""
        
        for i in range(self.message_size.get()):
            bits += str(random.randint(0,1))
        print(bits)
        self.message_source = "random"
        self.message_input.set(bits)
        self.message_source = "user"
        #self.validate_message()
    
    def message_changed(self, *args):
        self.invalidate_message()
        if self.message_source == "user":
            self.set_status("Message modified.")
        elif self.message_source == "random":
            self.set_status("Random message generated.")
            
    def is_valid_binary(self,text):
        return len(text) > 0 and all(bit in "01" for bit in text)
    
    def get_message_length(self):
        return len(self.message_input.get())
    
    def validate_message(self):
        self.message_valid=False
        self.message=""
        temp = self.message_input.get()
        if len(temp) == 0:
            self.set_status("Message is empty.")
            self.update_operation_buttons()
            return False
        if not self.is_valid_binary(temp):
                self.set_status("Invalid message.")
                self.update_operation_buttons()
                return False
        self.set_status(f"Message accepted. Length: {self.get_message_length()} bits.")
        self.message = temp
        self.message_length = self.get_message_length()
        self.message_valid=True
        self.update_operation_buttons()
        print("Stored message:",self.message)
        return True
    
    def invalidate_message(self):
        self.message_valid=False
        self.encoded_valid=False
        self.message=""
        self.encoded_data=""
        self.decoded_data=""
        self.clear_outputs()
        self.set_operation_buttons_state("disabled")
    
    def encode_data(self,message,scheme):
        if scheme == "Parity Check":
            print("Using Parity Check encoding.")
            encoded_result = self.encode_parity(message)
        elif scheme == "Non-Cyclic Hamming":
            print("Using Non-Cyclic Hamming encoding.")
            encoded_result = self.encode_hamming([int(bit) for bit in message])
        else:
            print("Encoding scheme not implemented.")
            encoded_result = message
        
        return encoded_result
        
    def encode_message(self):
        print("Encode button pressed.")
        if not self.message_valid:
            print("Encoding cancelled: No vaild message.")
            return
        self.clear_text_widget(self.decoded_text)
        self.clear_text_widget(self.analysis_text)
        selected_encoding = self.get_selected_encoding()
        print("Encoding Scheme:", selected_encoding)
        print("Message to encode: ", self.message)
        self.set_text_widget(self.original_text,self.message)
        encoded_result = self.encode_data(self.message,selected_encoding)
        if encoded_result:
            self.encoded_data=encoded_result
            self.encoded_valid=True
            
        else:
            self.encoded_data=""
            self.encoded_valid=False
        channel_sim.ChannelSimulator(self.encoded_data,self.codeword_size.get(),self.channel_complete)
        encoded_display = "".join(map(str,reversed(encoded_result)))
        self.set_text_widget(self.encoded_text, encoded_display)
        self.set_status(f"Encoding complete using {selected_encoding}.")
        self.update_operation_buttons()
        if self.get_selected_encoding() == "Non-Cyclic Hamming":
            self.show_encoding_visualization()
        
    def encoding_changed(self,*args):
        self.update_encoding_controls()
        if self.get_selected_encoding() == "Parity Check":
            self.codeword_size.set(0)
        else:
            self.codeword_size.set(7)
        
        if self.message_valid or self.encoded_valid:
            self.invalidate_message()
            self.set_status("Encoding scheme changed.")
        else:
            self.set_status("Encoding scheme selected.")
        print("Encoding scheme changed.")
        
    def decode_data(self,message,scheme):
        if scheme == "Parity Check":
            print("Using Parity Check decoding.")
            parity_valid = decoder.parity_compare(message,self.encoding_align.get())
            if parity_valid:
                error_report = "No parity error detected."
            else:
                error_report = "Parity error detected: the received codeword has incorrect parity."                    
            decoded_result = None
            error_positions = error_report
        elif scheme == "Non-Cyclic Hamming":
            print("Using Non-Cyclic Hamming decoding.")
            decoded_result, error_positions = self.decode_hamming(self.received_data)
        elif scheme == "Cyclic Hamming":
            print("Using Cyclic Hamming decoding.")
            decoded_result = self.encoded_data
            error_positions = None
        elif scheme == "Binary Golay":
            print("Using Binary Golay decoding.")
            decoded_result = self.encoded_data
            error_positions = None
        else:
            print("Decoding scheme not implemented.")
            decoded_result = self.encoded_data
            error_positions = None
        return decoded_result, error_positions
        
    def decode_message(self):
        print("Decode button pressed.")
        if not self.encoded_valid:
            print("Decoding cancelled: No valid message.")
            self.set_text_widget(self.analysis_text,"No message available.")
            return
        self.set_status("Decoding...")
        selected_encoding = self.get_selected_encoding()
        decoded_result, error_positions = self.decode_data(self.received_data,selected_encoding)
        if selected_encoding == "Parity Check":
            self.decoded_data = ""
            self.set_text_widget(self.decoded_text, "")
            self.set_text_widget(self.analysis_text, error_positions)
        else:
            self.decoded_data = decoded_result
            decoded_display = "".join(map(str,decoded_result))
            if error_positions is None:
                error_display = "No errors detected."
            else:
                error_messages = []
                for block_number, position in enumerate(error_positions,start=1):
                    if position is not None:
                        error_messages.append(
                            f"Block {block_number}: "
                            f"Single-bit error corrected at "
                            f"bit position {position}.")
                if len(error_messages) == 0:
                    error_display = "No errors detected."
                else:
                    error_display = "\n".join(error_messages)
            self.set_text_widget(self.decoded_text, decoded_display)
            self.set_text_widget(self.analysis_text, error_display)
        self.set_status(f"Decoding complete using {selected_encoding}.")
        
    
    ###########################################################################
    ############################# Helpers Stuff ###############################
    ###########################################################################
    def handle_keyboard(self,event):
        key = event.keysym
        if key == "g":
            self.generate_button.invoke()
        elif key == "c":
            self.message_accept_button.invoke()
        elif key == "e":
            self.encode_button.invoke()
        elif key == "d":
            self.decode_button.invoke()
        elif key == "x":
            self.clear_button.invoke()
        elif key == "Escape":
            self.window.destroy()
        
    def get_selected_encoding(self):
        return self.encoding.get()
    
    def set_status(self,text):
        self.status_text.set("Message Status: " + text)
    
    def set_parity(self,parity_type):
        self.encoding_align.set(parity_type)
    
    def set_scheme_select(self,scheme):
        self.scheme_select_text.set("Current (n, k): " + scheme)
    
    def select_sevenfour(self):
        self.set_codeword_size(7)
        self.set_scheme_select("(7, 4)")
    
    def select_fifteeneleven(self):
        self.set_codeword_size(15)
        self.set_scheme_select("(15, 11)")
    
    def select_thirtytwenty(self):
        self.set_codeword_size(31)
        self.set_scheme_select("(31, 26)")
    
    def select_sixtyfifty(self):
        self.set_codeword_size(63)
        self.set_scheme_select("(63, 57)")
    
    def set_operation_buttons_state(self,state):
        self.encode_button.config(state=state)
        self.decode_button.config(state=state)
    
    def set_text_widget(self,widget,text):
        widget.config(state="normal")
        widget.delete("1.0",tk.END)
        widget.insert("1.0",text)
        widget.config(state="disabled")
    
    def update_operation_buttons(self):
        if self.message_valid:
            self.encode_button.config(state="normal")
        else:
            self.encode_button.config(state="disabled")
        if self.received_valid:
            self.decode_button.config(state="normal")
        else:
            self.decode_button.config(state="disabled")
    
    def clear_text_widget(self,widget):
        widget.config(state="normal")
        widget.delete("1.0",tk.END)
        widget.config(state="disabled")
        
    def clear_outputs(self):
        self.original_output.set("")
        self.encoded_output.set("")
        self.received_output.set("")
        self.decoded_output.set("")
        self.errors_output.set("")
        self.clear_text_widget(self.original_text)
        self.clear_text_widget(self.encoded_text)
        self.clear_text_widget(self.received_text)
        self.clear_text_widget(self.decoded_text)
        self.clear_text_widget(self.analysis_text)
    
    def clear_message(self):
        self.message_input.set("")
        self.invalidate_message()
        self.set_status("Awaiting message...")
        print("Message cleared.")
        
    def update_encoding_controls(self):
        if self.encoding.get() == "Parity Check":
            self.scheme_select_frame.grid_remove()
        else:
            self.scheme_select_frame.grid()
        if self.encoding.get() == "Non-Cyclic Hamming" or self.encoding.get() == "Cyclic Hamming":
            self.scheme_frame.grid()
        else:
            self.scheme_frame.grid_remove()
    
    def is_parity_position(self,bit_position):
        return bit_position&(bit_position-1)==0
        
    def get_data_position(self,bit_position,parity_position):
        return sum(
            1
            for position in range(1,bit_position+1)
            if position not in parity_position)
    
    def get_parity_positions(self,parity_positions):
        return [
            position
            for position in range(1,self.codeword_size.get()+1)
            if position not in parity_positions]
    
    def get_parity_coverage(self,parity_position):
        return [
            position
            for position in range(1,self.codeword_size.get()+1)
            if position & parity_position]
    
    def encode_parity(self,message):
        encoded_data = encoder.encode_parity(message,self.encoding_align.get())
        return encoded_data
    
    def decode_parity(self,received_data):
        parity_valid = decoder.parity_compare(received_data,self.encoding_align.get())
        if parity_valid:
            return "No parity error detected."
        else:
            return "Parity error detected: the received codeword has incorrect parity."
    
    def encode_hamming(self,message):
        encoded_data = encoder.encode_hamming(message, self.codeword_size.get())
        return encoded_data
    
    def channel_complete(self,received_data):
        self.received_data = received_data
        received_display = "".join(map(str,reversed(received_data)))
        self.set_text_widget(self.received_text,received_display)
        #self.decode_message()
        print("Received data:",received_data)
        self.received_valid=True
        self.update_operation_buttons()
    
    def decode_hamming(self,codeword):
        decoded_data, error_position = decoder.decode_hamming(codeword,self.codeword_size.get(),self.message_length)
        return decoded_data, error_position
    
    def get_cell_label(self,bit_position,parity_positions):
        if self.is_parity_position(bit_position):
            return f"p{bit_position}"
        data_position = self.get_data_position(bit_position, parity_positions)
        return f"d{data_position}"
    
    def draw_row_label(self,label,x,y,cell_height):
        self.visualization_canvas.create_text(x,y+cell_height/2,text=label,anchor="e")
            
    def draw_parity_row(self,parity_position,x_start,y,cell_width,cell_height):
        self.visualization_canvas.create_text(x_start-5,y+cell_height/2,text=f"p{parity_position}",anchor="e")
        for bit_position in range(self.codeword_size.get(),0,-1):
            x = x_start + (self.codeword_size.get() - bit_position) * cell_width
            if bit_position == parity_position:
                cell_text="P"
            elif bit_position in self.get_parity_coverage(parity_position):
                cell_text="X"
            else:
                cell_text=""
            self.visualization_canvas.create_rectangle(x,y,x+cell_width,y+cell_height,outline="black")
            self.visualization_canvas.create_text(x+cell_width/2,y+cell_height/2,text=cell_text)
    
    def get_test_bits(self):
        return [
            "1" if position % 2 == 1 else "0"
            for position in range(1,self.codeword_size.get()+1)]
    
    def show_encoding_visualization(self):
        if hasattr(self, "visualization_window"):
            if self.visualization_window.winfo_exists():
                self.visualization_window.lift()
                return
        
        self.visualization_window = tk.Toplevel(self.window)
        self.visualization_window.title("Encoding Visualization")
        parent_x = self.window.winfo_x() + 880
        parent_y = self.window.winfo_y()
        self.visualization_window.geometry(f"1080x500+{parent_x}+{parent_y}")
        self.visualization_window.minsize(1000,400)
        ttk.Label(
            self.visualization_window,
            text="Encoding Visualization",
            style="OutHeading.TLabel").pack(fill="x",padx=10,pady=10)
        self.visualization_canvas = tk.Canvas(
            self.visualization_window,
            background="white")
        self.visualization_canvas.pack(fill="both",expand=True,padx=10,pady=(10,0))
        self.visualization_scrollbar = ttk.Scrollbar(
            self.visualization_window,
            orient="horizontal",
            command=self.visualization_canvas.xview)
        self.visualization_scrollbar.pack(fill="x",padx=10,pady=(10,0))
        self.visualization_canvas.configure(xscrollcommand=self.visualization_scrollbar.set)
        
        cell_width=30
        cell_height=25
        extra_height=15
        x_start=90
        y_start=20
        for bit_position in range(self.codeword_size.get(),0,-1):
            x=x_start+(self.codeword_size.get()-bit_position)*cell_width
            self.visualization_canvas.create_rectangle(x,y_start,x+cell_width,y_start+cell_height,outline="black")
            self.visualization_canvas.create_text(x+cell_width/2,y_start+cell_height/2, text=str(bit_position))
        
        parity_positions=[]
        parity_position=1
        while parity_position <= self.codeword_size.get():
            parity_positions.append(parity_position)
            parity_position*=2
            
        encoded_bits=self.encoded_data
        data_y=y_start+cell_height
        for bit_position in range(self.codeword_size.get(),0,-1):
            x=x_start+(self.codeword_size.get()-bit_position)*cell_width
            cell_text=self.get_cell_label(bit_position, parity_positions)
            self.visualization_canvas.create_rectangle(x,data_y,x+cell_width,data_y+cell_height+extra_height,outline="black")
            bit_value=encoded_bits[bit_position-1]
            self.visualization_canvas.create_text(x+cell_width/2,data_y+7+cell_height/2,text=f"{cell_text}\n{bit_value}")
        
        self.draw_row_label("Bit Position",x_start-10,y_start,cell_height)
        self.draw_row_label("Encoded Data",x_start-10,data_y,cell_height)
        cell_height=25
        parity_y=data_y+cell_height
        parity_position=1
        while parity_position <= self.codeword_size.get():
            parity_y += cell_height
            self.draw_parity_row(parity_position,x_start,parity_y,cell_width,cell_height)
            parity_position*=2

            
        self.visualization_canvas.configure(
            scrollregion=(0,0,self.codeword_size.get()*cell_width+x_start,parity_y+cell_height))
    
    
    
    
    
    def run(self):
        self.window.lift()
        self.window.focus_force()
        self.window.mainloop()
        
app = BlockCodeGUI()
app.run()
