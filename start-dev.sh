echo "Start..."
git init && \
git remote add origin https://github.com/nahualventure/react-native.git && \
git fetch origin exeboard-1-24-0 && \
git reset --hard origin/exeboard-1-24-0 && \
git checkout exeboard-1-24-0 && \
echo "Success"
