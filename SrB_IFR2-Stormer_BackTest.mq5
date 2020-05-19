#property copyright   "Sandro Boschetti - 18/05/2020"
#property description "Programa implementado em MQL5/Metatrader5"
#property description "Realiza backtests do método IFR2 do Stormer"
#property link        "http://lattes.cnpq.br/9930983261299053"
#property version     "1.00"
#property indicator_separate_window

//--- input parameters
#property indicator_buffers 1
#property indicator_plots   1
//---- plot RSIBuffer
#property indicator_label1  "Stormer-IFR2"
#property indicator_type1   DRAW_LINE
#property indicator_color1  Red
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- input parameters
input int periodo = 2;                      //número de períodos
input double capitalInicial = 30000.00;     //Capital Inicial
input bool reaplicar = true;                //true: reaplicar o capital
input datetime t1 = D'2015.01.01 00:00:00'; //data inicial
input datetime t2 = D'2020.01.01 00:00:01'; //data final

double ch = 0;
double up = 0;
double down = 0;
double medUp = 0;
double medDown = 0;
double relativeStrength = 0;
double rsi = 0;
bool comprado = false;
bool jaCalculado = false;


//--- indicator buffers
double         RSIBuffer[];
//--- global variables
//bool tipoExpTeste = tipoExp;

int OnInit() {
   SetIndexBuffer(0,RSIBuffer,INDICATOR_DATA);
   IndicatorSetString(INDICATOR_SHORTNAME,"Stormer-IFR2("+string(periodo)+")");
   return(0);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]) {
   
// Cálculo de valores prévios para o cálculo do primeiro valor do IFR   
   for(int i=0; i<periodo; i++){
      ch = close[i+1] + close[i];
      if(ch>0){
         up = ch;
      }else{
         up = 0;
      }
      if(ch<0){
         down = -1*ch;
      }else{
         down = 0;
      }
      medUp = medUp + up/periodo;        //média aritimética 
      medDown = medDown + down/periodo;  //média aritimética 
   }

// Para garantir que não haverá divisão por zero. REVER ESSA PARTE  
   if(medDown!=0){
      relativeStrength = medUp / medDown;
   }else{
      relativeStrength = 1;
   }
   
// Primeiro valor do IFR que começa a existir em período+1   
   rsi = 100 - 100/(relativeStrength + 1);
   RSIBuffer[periodo+1] = rsi;

// Calculo dos demais valores de IFR   
   for(int i=periodo+2; i<rates_total; i++){
      ch = close[i] - close[i-1];
      if(ch>0){
         up = ch;
      }else{
         up = 0;
      }
      if(ch<0){
         down = -1*ch;
      }else{
         down = 0;
      }
      medUp = (medUp*(periodo-1) + up) / periodo;       // cálculo de MME
      medDown = (medDown*(periodo-1) + down) / periodo; // cálculo de MME
      
      if(medDown!=0){
        relativeStrength = medUp / medDown;
      }else{
         relativeStrength = 1;
      }
      rsi = 100 - 100/(relativeStrength + 1); 
      RSIBuffer[i] = rsi;     
   }
// Aqui termina o cálculo do IFR. Toda essa parte poder provavelmente
// ter sido obtida por meio dos funções internas do sistema.
   
   
   int nOp = 0;
   double capital = capitalInicial;
   int nAcoes = 0;
   double preco = 0;
   double lucroOp = 0;
   double lucroAcum = 0;
   double acumPositivo = 0;
   double acumNegativo = 0;
   int nAcertos = 0;
   int nErros = 0;
   double max = 0;
   
//   datetime t1 = D'2015.01.01 00:00:00';
//   datetime t2 = D'2020.01.01 00:00:01';
   
   int nPregoes = 0;
   int nPregoesPos = 0;
   
   datetime diaDaEntrada = time[0];
   
   for(int i=periodo+1; i<rates_total;i++){
   
      if (time[i]>=t1 && time[i]<t2) {
      
         nPregoes++;
         if(comprado){nPregoesPos++;}
      
         // Se posiciona na compra
         if(RSIBuffer[i]<25 && !comprado){
            preco = close[i];
            nAcoes = 100 * floor(capital / (100*preco));
            comprado = true;
            nOp++;
            diaDaEntrada = time[i];
         }
      
         // definição do valor máximo dos 2 últimos candles
         if(high[i-1]>high[i-2]){
            max = high[i-1];
         }else{
            max = high[i-2];
         }
      
         // Faz a venda --- Não faz a venda no mesmo dia da compra
         if(comprado && (high[i]>=max) && (diaDaEntrada != time[i])){
            lucroOp = (max - preco) * nAcoes;
            if(lucroOp>0){
               nAcertos++;
               acumPositivo = acumPositivo + lucroOp;
            }else{
               nErros++;
               acumNegativo = acumNegativo + lucroOp;
            }
            lucroAcum = lucroAcum + lucroOp;
            if(reaplicar == true){capital = capital + lucroOp;}
            nAcoes = 0;
            preco = 0;
            comprado = false;
         }
   } // fim do "if" do intervalo de tempo 
   } // fim fo "for"
   
   
   double  dias = (t2-t1)/(60*60*24);
   double  anos = dias / 365.25;
   double meses = anos * 12;
   double rentTotal = 100.0*((lucroAcum+capitalInicial)/capitalInicial - 1);
   double rentMes = 100.0*(pow((1+rentTotal/100.0), 1/meses) - 1);

   string nome = Symbol();

   if(!jaCalculado){
      printf("Ativo: %s", nome);
      if(reaplicar){printf("Reinvestimento dos lucros: SIM");}else{printf("Reinvestimento dos lucros: NÃO");}
      printf("#Op: %d, #Pregoes: %d, Capital Inicial: %.2f", nOp, nPregoes, capitalInicial);
      printf("lucro: %.2f, Capital Final: %.2f",  floor(lucroAcum), floor(capital));
      printf("#Acertos: %d (%.2f%%), #Erros: %d (%.2f%%)", nAcertos, 100.0*nAcertos/nOp,  nErros, 100.0*nErros/nOp);
      printf("#PregoesPosicionado: %d, #pregoes/Op: %.2f", nPregoesPos, 1.0*nPregoesPos/nOp);
      printf("Rentabilidade mensal: %.2f%% (juros compostos) ou %.2f%% (juros simples)", rentMes, rentTotal/meses);
      printf("Somatório dos valores positivos: %.2f e negativos: %.2f e diferença: %.2f", acumPositivo, acumNegativo, acumPositivo+acumNegativo);
      //printf("Pay-off: %.2f", - (acumPositivo/nAcertos) / (acumNegativo/nErros));
   }
   jaCalculado = true;

   return(rates_total);
}

