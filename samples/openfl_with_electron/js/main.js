const { app, BrowserWindow } = require('electron')
const path = require('path')

function createWindow () {
  const win = new BrowserWindow({
    width: 800,
    height: 600,
	useContentSize: true,
    webPreferences: {
	    nodeIntegration: true, // required for file system access
        contextIsolation: false // required for file system access
    }
  })
  win.setResizable(false)
  win.removeMenu()
  win.loadFile('index.html')
  //win.webContents.openDevTools()
}

app.whenReady().then(() => {
  createWindow()

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow()
    }
  })
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit()
  }
})
