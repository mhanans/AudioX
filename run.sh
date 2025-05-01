#!/bin/bash

# Function to detect CUDA availability
detect_cuda() {
    if command -v nvidia-smi &>/dev/null; then
        CUDA_VERSION=$(nvidia-smi | grep "CUDA Version" | awk '{print $9}' | cut -d'.' -f1-2)
        if [ -n "$CUDA_VERSION" ]; then
            echo "CUDA $CUDA_VERSION detected"
            return 0
        fi
    fi
    echo "No CUDA detected, will use CPU version"
    return 1
}

# Function to install Miniconda
install_miniconda() {
    local sys_arch=$(uname -m)
    case "${sys_arch}" in
    x86_64*) sys_arch="x86_64" ;;
    arm64*|aarch64*) sys_arch="aarch64" ;;
    *) echo "Unsupported system architecture: ${sys_arch}"; exit 1 ;;
    esac

    local miniconda_url="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-${sys_arch}.sh"
    if ! "${CONDA_ROOT}/bin/conda" --version &>/dev/null; then
        mkdir -p "$INSTALL_DIR"
        curl -Lk "$miniconda_url" >"$INSTALL_DIR/miniconda_installer.sh"
        chmod u+x "$INSTALL_DIR/miniconda_installer.sh"
        bash "$INSTALL_DIR/miniconda_installer.sh" -b -p "$CONDA_ROOT"
        rm -rf "$INSTALL_DIR/miniconda_installer.sh"
    fi
    echo "Miniconda installed at $CONDA_ROOT"
}

# Function to create Conda environment
create_conda_env() {
    if [ ! -d "$ENV_DIR" ]; then
        echo "Creating Conda environment with Python $PYTHON_VERSION at $ENV_DIR"
        "${CONDA_ROOT}/bin/conda" create -y -k --prefix "$ENV_DIR" python="$PYTHON_VERSION" || {
            echo "Failed to create Conda environment."
            rm -rf "$ENV_DIR"
            exit 1
        }
    else
        echo "Conda environment already exists at $ENV_DIR"
    fi
}

# Function to activate Conda environment
activate_conda_env() {
    source "$CONDA_ROOT/etc/profile.d/conda.sh"
    conda activate "$ENV_DIR" || {
        echo "Failed to activate environment. Remove $ENV_DIR and run the script again."
        exit 1
    }
    echo "Conda environment activated at $CONDA_PREFIX"
}

# Function to download model files
download_model_files() {
    echo "Checking and downloading required model files..."
    
    # Create model directory if it doesn't exist
    mkdir -p model
    
    # Download model.ckpt if it doesn't exist
    if [ ! -f "model/model.ckpt" ]; then
        echo "Downloading model.ckpt..."
        wget https://huggingface.co/HKUSTAudio/AudioX/resolve/main/model.ckpt -O model/model.ckpt || {
            echo "Failed to download model.ckpt"
            exit 1
        }
    else
        echo "model.ckpt already exists"
    fi
    
    # Download config.json if it doesn't exist
    if [ ! -f "model/config.json" ]; then
        echo "Downloading config.json..."
        wget https://huggingface.co/HKUSTAudio/AudioX/resolve/main/config.json -O model/config.json || {
            echo "Failed to download config.json"
            exit 1
        }
    else
        echo "config.json already exists"
    fi
    
    echo "All required model files are present"
}

# Function to install dependencies
install_dependencies() {
    echo "Installing dependencies..."
    
    # Install PyTorch and torchvision with specific versions based on CUDA availability
    if detect_cuda; then
        echo "Installing PyTorch with CUDA $CUDA_VERSION support..."
        pip install torch==2.0.1 torchvision==0.15.2 torchaudio==2.0.2 --index-url https://download.pytorch.org/whl/cu118 || {
            echo "Failed to install torch and torchvision with CUDA support."
            exit 1
        }
    else
        echo "Installing PyTorch CPU version..."
        pip install torch==2.0.1 torchvision==0.15.2 torchaudio==2.0.2 --index-url https://download.pytorch.org/whl/cpu || {
            echo "Failed to install torch and torchvision CPU version."
            exit 1
        }
    fi
    
    # Install ffmpeg and libsndfile
    conda install -y -c conda-forge ffmpeg libsndfile || {
        echo "Failed to install ffmpeg and libsndfile."
        exit 1
    }
    
    # Install project dependencies
    pip install -e . || {
        echo "Failed to install project dependencies."
        exit 1
    }
}

# Function to run Gradio
run_gradio() {
    echo "Running Gradio interface..."
    python run_gradio.py --model-config model/config.json --share || {
        echo "Failed to run Gradio."
        exit 1
    }
}

# Main execution
INSTALL_DIR="$(pwd)/install_dir"  # Installation directory
CONDA_ROOT="$INSTALL_DIR/conda"   # Miniconda location
ENV_DIR="$INSTALL_DIR/env"        # Conda environment location
PYTHON_VERSION="3.8.20"           # Python version to use (as specified in README)

echo "******************************************************"
echo "Setting up Miniconda"
echo "******************************************************"
install_miniconda

echo "******************************************************"
echo "Creating Conda environment"
echo "******************************************************"
create_conda_env
activate_conda_env

echo "******************************************************"
echo "Installing dependencies"
echo "******************************************************"
install_dependencies

echo "******************************************************"
echo "Downloading model files"
echo "******************************************************"
download_model_files

echo "******************************************************"
echo "Running Gradio interface"
echo "******************************************************"
run_gradio 