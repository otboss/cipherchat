const command = function(botID){
  return `
output`+botID.toString()+`=$(curl -d \
"username=bot`+botID.toString()+`&\
publicKey=872648736492384792387498&\
publicKey2=080234803249832432423809&\
passphrase=" -X POST https://127.0.0.1:6333/newgroup -k); printf "Output from \
bot`+botID.toString()+`: "$output`+botID.toString()+`'\n';
`;
}

const intensityLevel = 10;
const pulseIntensity = 2;
//Endpoint stress test
(async () => {
  for(let x = 0; x < intensityLevel; x++){
    setInterval(() => {
      let pulseArr = [];
      for(let y = 0; y < pulseIntensity; y++){
        pulseArr.push(new Promise(function(resolve, reject){
          require("child_process").exec(command(x), function (error, stdout, stderror) {
            if (error)
              console.log('[ERROR]: ' + error);
            else
              console.log(stderror+"\n"+stdout);
            resolve();
          });
        }));
      }      
      Promise.all(pulseArr);
    }, 600);
  }
})();