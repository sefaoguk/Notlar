# Buildx Install
Dockerfile'in farkli islemcilerdeki platformlarda calisabilmesi icin dockerda buildx'in yuklu olmasi gerekmekte.
Her ne kadar 18.x versiyonundan sonra varsayilan olarak yuklu geliyor olsa da localdeki mevcut surumde olmadigini gordum. 
Yuklemek icin asagidaki adimlari deneyiniz:
  * sudo apt-get update;
    
  * sudo apt-get upgrade docker (ya da docker-ce,docker.io hangi paket kullaniliyorsa);
    
  * mkdir -p ~/.docker/cli-plugins;
    
  * curl -SL https://github.com/docker/buildx/releases/download/v0.6.1/buildx-v0.6.1.linux-amd64 \ -o ~/.docker/cli-plugins/docker-buildx;
  
  * chmod a+x ~/.docker/cli-plugins/docker-buildx;



# Image Create and Push With Buildx 
Buildx yuklendikten sonra eger imajiniz localinizde calisiyor ise asagidaki adimlarla uygulamayi clouda pushlayabilirsiniz.

** Burada imaj olusturdugumuzda default buildx olarak amd64 kullanilmaktadir. Ondan dolayi yeni bir buildx create ediyoruz ve onun kullanilmasi --use parametresi ile saglanmaktadir.**
  * docker buildx create --name mybuilder --use;

** islenilen cloud'a pushlanilmasi icin login islemi (github or dockerhub) **
  * echo "GITHUB_PERSONAL_ACCESS_TOKEN" | docker login ghcr.io -u GITHUB_USERNAME --password-stdin;
  *  echo "DOCKER_PASS_OR_ACCESS_TOKEN" | docker login --password-stdin;

** Burada uygulamanin buildini, farkli platformlarda calisacak sekilde alarak istenilen cloud'a pushlanmaktadir. **
  * docker buildx build --platform linux/arm64,linux/arm/v7 -t dockerhuborgithub/reponame --push ;
