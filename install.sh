echo "   ___                   _                _   __                     _ "
echo "  |_  |                 | |              | | / /                    | |"
echo "    | |_   _ _ __  _   _| |_ ___ _ __    | |/ /  ___ _ __ _ __   ___| |"
echo "    | | | | | '_ \| | | | __/ _ \ '__|   |    \ / _ \ '__| '_ \ / _ \ |"
echo "/\__/ / |_| | |_) | |_| | ||  __/ |      | |\  \  __/ |  | | | |  __/ |"
echo "\____/ \__._| .__/ \__. |\__\___|_|      | \_/\___|_|  |_| |_|\___|_|"
echo "            | |     __/ |                                                    "
echo "            |_|    |___/                                                     "


repository="https://github.com/stisa/jupyter-nim-kernel.git"
repo_name="jupyter-nim-kernel"

set -x

echo ":: Installing python module Nim kernel."
pip install $repo_name; echo "Done. "
echo ":: Cloning Jupyter Nim-kernel... "
git clone $repository $repo_name; echo "Done. "
echo ":: Installing kernel specification"
cd $repo_name
jupyter-kernelspec install nim_spec/ ; echo "Done."
echo ":: Removing repository"
cd ..
rm -rf jupyter-nim-kernel/
echo "Completed! Installation successful. You can type jupyter-notebook and be happy"
