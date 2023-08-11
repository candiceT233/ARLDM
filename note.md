# Environment Setup Note
After running `pip install -r requirements.txt` \

```bash
pip install pytorch-lightning==1.4.0 torch
pip install torchmetrics==0.6.0
# pip install torchaudio==0.13.0 torch==1.13.0
pip install pytorch-lightning==1.9.*
pip install lightning_bolts==0.7.0
# pip install accelerate
```


## torch==1.4.0
- Issue : https://github.com/Lightning-AI/lightning/discussions/11664

Need following changes in `main.py` to use v1.4.0 \
line-16 and line-418:
```python 
from pytorch_lightning.plugins import DDPPlugin
...
        plugins=DDPPlugin(find_unused_parameters=False)
```
Original:
```
from pytorch_lightning.strategies import DDPStrategy
...
        strategy=DDPStrategy(find_unused_parameters=False)
```

Other possible issues: 
- https://github.com/microsoft/DeepSpeed/issues/2845
Version above torch==1.4.0 shows below error:
```
    from torch._six import string_classes
ModuleNotFoundError: No module named 'torch._six'
```


## torchaudio
```bash
pip install torchaudio==0.7.2 torch==1.7.1 
pip install torchaudio==0.6.0 torch==1.6.0 # forced torch version
pip install torchaudio==0.13.0 torch==1.13.0 # forced torch version
pip install torchaudio==2.0.1 torch==2.0.0 # forced torch version
pip install torchaudio==2.0.2 torch==2.0.1 # forced torch version
```

```bash
ERROR: Could not find a version that satisfies the requirement torchaudio==1.8.0 (from versions: 0.4.0, 0.5.0, 0.5.1, 0.6.0, 0.7.0, 0.7.2, 0.8.0, 0.8.1, 0.9.0, 0.9.1, 0.10.0, 0.10.1, 0.10.2, 0.11.0, 0.12.0, 0.12.1, 0.13.0, 0.13.1, 2.0.0, 2.0.1, 2.0.2)
ERROR: No matching distribution found for torchaudio==1.8.0

lightning-bolts 0.5.0 requires torch>=1.7.1
```

## Others
comment out `accelerator='gpu'`

## train
need to add log path, `pororo_test` is the `run_name` in `config.yml`
```
mkdir -p save_ckpt/pororo_test/log
```