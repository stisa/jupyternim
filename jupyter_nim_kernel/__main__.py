from ipykernel.kernelapp import IPKernelApp
from .kernel import NimKernel
IPKernelApp.launch_instance(kernel_class=NimKernel)
